aux_scan = module

include (green_t)
include (aux)
include (aux_util)
include (aux_control)
include (aux_util_color)

local info, history = aux_info, aux_history

local PAGE_SIZE = 50

do
	local scan_states = t

	function public.start(params)
		for old_state in present(scan_states[params.type]) do
			abort(old_state.id)
		end
		local thread_id = thread(wait_for_callback, params.on_scan_start, scan)
		scan_states[params.type] = {
			id = thread_id,
			params = params,
		}
		return thread_id
	end

	function public.abort(scan_id)
		local aborted = t
		for type, state in scan_states do
			if not scan_id or state.id == scan_id then
				kill_thread(state.id)
				scan_states[type] = nil
				tinsert(aborted, state)
			end
		end
		for _, state in aborted do
			do (state.params.on_abort or nop)() end
		end
	end

	function private.complete()
		local on_complete = state.params.on_complete
		scan_states[state.params.type] = nil
--		for _ in on_complete or nop do end TODO test performance
		do (on_complete or nop)() end
	end

	function private.state.get()
		for _, state in scan_states do
			if state.id == thread_id then
				return state
			end
		end
	end
end

function private.query.get()
	return state.params.queries[state.query_index]
end

private.wait_for_callback = vararg-function(arg)
	local send_signal, signal_received = signal()
	local suspended, ret

	local f = tremove(arg, 1)
	local k = tremove(arg)

	if f then
		tinsert(arg, T(
			'suspend', function() suspended = true end,
			'resume', send_signal
		))
		f(unpack(arg))
	end
	if not suspended then send_signal() end

	return when(signal_received, function() return k(unpack(signal_received())) end)
end

function private.total_pages(total_auctions)
    return ceil(total_auctions / PAGE_SIZE)
end

function private.last_page(total_auctions)
    local last_page = max(total_pages(total_auctions) - 1, 0)
    local last_page_limit = query.blizzard_query and query.blizzard_query.last_page or last_page
    return min(last_page_limit, last_page)
end

function private.scan()
	state.query_index = state.query_index and state.query_index + 1 or 1
	if query and (index(query.blizzard_query, 'first_page') or 0) <= (index(query.blizzard_query, 'last_page') or huge) then
		if query.blizzard_query then
			state.page = query.blizzard_query.first_page or 0
		else
			state.page = nil
		end
		return wait_for_callback(state.params.on_start_query, state.query_index, process_query)
	else
		complete()
	end
end

function private.process_query()
	return (query.blizzard_query and submit_query or scan_page)()
end

function private.submit_query()
	when(function() return state.params.type ~= 'list' or CanSendAuctionQuery() end, function()
		do (state.params.on_submit_query or nop)() end
		state.last_query_time = GetTime()
		if state.params.type == 'bidder' then
			GetBidderAuctionItems(state.page)
		elseif state.params.type == 'owner' then
			GetOwnerAuctionItems(state.page)
		else
			local blizzard_query = query.blizzard_query or t
			QueryAuctionItems(
				blizzard_query.name,
				blizzard_query.min_level,
				blizzard_query.max_level,
				blizzard_query.slot,
				blizzard_query.class,
				blizzard_query.subclass,
				state.page,
				blizzard_query.usable,
				blizzard_query.quality
			)
		end
		return wait_for_results()
	end)
end

function private.scan_page(i)
	i = i or 1
	local recurse = function(retry)
		if i >= PAGE_SIZE then
			wait_for_callback(state.params.on_page_scanned, function()
				if query.blizzard_query and state.page < last_page(state.total_auctions) then
					state.page = state.page + 1
					return process_query()
				else
					return scan()
				end
			end)
		else
			return scan_page(retry and i or i + 1)
		end
	end

	local auction_info = info.auction(i, state.params.type)
	if auction_info and (auction_info.owner or state.params.ignore_owner or aux_ignore_owner) then
		auction_info.index = i
		auction_info.page = state.page
		auction_info.blizzard_query = query.blizzard_query
		auction_info.query_type = state.params.type

		history.process_auction(auction_info)

		if (state.params.auto_buy_validator or nop)(auction_info) then
			local send_signal, signal_received = signal()
			when(signal_received, recurse)
			place_bid(auction_info.query_type, auction_info.index, auction_info.buyout_price, papply(send_signal, true))
			return thread(when, later(GetTime(), 10), send_signal, false)
		elseif not query.validator or query.validator(auction_info) then
			return wait_for_callback(state.params.on_auction, auction_info, function(removed)
				if removed then
					return recurse(true)
				else
					return recurse()
				end
			end)
		end
	end

	return recurse()
end

function private.wait_for_results()
	local timeout = later(state.last_query_time, 10)
	local send_signal, signal_received = signal()
	when(signal_received, function()
        if timeout() then
            return submit_query()
        else
            _,  state.total_auctions = GetNumAuctionItems(state.params.type)
            return wait_for_callback(
                state.params.on_page_loaded,
                state.page - (query.blizzard_query.first_page or 0) + 1,
                last_page(state.total_auctions) - (query.blizzard_query.first_page or 0) + 1,
                total_pages(state.total_auctions) - 1,
                scan_page
            )
        end
    end)

    thread(when, timeout, send_signal)

    if state.params.type == 'bidder' then
        return thread(when, function() return bids_loaded end, send_signal)
    elseif state.params.type == 'owner' then
        return wait_for_owner_results(send_signal)
    elseif state.params.type == 'list' then
        return wait_for_list_results(send_signal, signal_received)
    end
end

function private.wait_for_owner_results(send_signal)
    if state.page == current_owner_page then
        return send_signal()
    else
        return on_next_event('AUCTION_OWNED_LIST_UPDATE', send_signal)
    end
end

function private.wait_for_list_results(send_signal, signal_received)
    local updated, last_update
    event_listener('AUCTION_ITEM_LIST_UPDATE', function(kill)
	    kill(signal_received())
        last_update = GetTime()
        updated = true
    end)
    local ignore_owner = state.params.ignore_owner or aux_ignore_owner
    return thread(when, function()
        -- short circuiting order important, owner_data_complete must be called iif an update has happened.
        local ok = updated and (ignore_owner or owner_data_complete('list')) or last_update and GetTime() - last_update > 5
        updated = false
        return ok
    end, send_signal)
end

function private.owner_data_complete(type)
    for i = 1, PAGE_SIZE do
        local auction_info = info.auction(i, type)
        if auction_info and not auction_info.owner then
	        return false
        end
    end
    return true
end
