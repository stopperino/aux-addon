aux_search_tab_results = module

include (green_t)
include (aux)
include (aux_util)
include (aux_control)
include (aux_util_color)

function LOAD()
	include (aux_search_tab)
	new_search('')
	current_search.dummy = true
	update_auto_buy_filter()
end

local info, scan = aux_info, aux_scan

aux_auto_buy_filter = ''

do
	local function action()
		aux_auto_buy_filter = _G[this:GetParent():GetName() .. 'EditBox']:GetText()
		update_auto_buy_filter()
	end

	StaticPopupDialogs.AUX_SEARCH_AUTO_BUY_FILTER = {
		text = 'Enter a filter for automatic buyout.',
		button1 = 'Accept',
		button2 = 'Cancel',
		hasEditBox = 1,
		OnShow = function()
			local edit_box = _G[this:GetName() .. 'EditBox']
			edit_box:SetMaxLetters(nil)
			edit_box:SetFocus()
			edit_box:HighlightText()
		end,
		OnAccept = action,
		EditBoxOnEnterPressed = function()
			action()
			this:GetParent():Hide()
		end,
		EditBoxOnEscapePressed = function()
			this:GetParent():Hide()
		end,
		timeout = 0,
		hideOnEscape = 1,
	}
end

do
	local id = 0
	function public.search_scan_id.get() return id end
	function public.search_scan_id.set(v) id = v end
end
do
	local validator
	function public.auto_buy_validator.get() return validator end
	function public.auto_buy_validator.set(v) validator = v end
end

do
	local searches = t
	local search_index = 1

	function public.current_search.get()
		return searches[search_index]
	end

	function private.update_search(index)
		searches[search_index].status_bar:Hide()
		searches[search_index].table:Hide()
		searches[search_index].table:SetSelectedRecord()

		search_index = index

		searches[search_index].status_bar:Show()
		searches[search_index].table:Show()

		search_box:SetText(searches[search_index].filter_string)
		if search_index == 1 then
			previous_button:Disable()
		else
			previous_button:Enable()
		end
		if search_index == getn(searches) then
			next_button:Hide()
			search_box:SetPoint('LEFT', previous_button, 'RIGHT', 4, 0)
		else
			next_button:Show()
			search_box:SetPoint('LEFT', next_button, 'RIGHT', 4, 0)
		end
		update_start_stop()
		update_continuation()
	end

	function private.new_search(filter_string)
		while getn(searches) > search_index do
			tremove(searches)
		end
		local search = T('filter_string', filter_string, 'records', t)
		tinsert(searches, search)
		if getn(searches) > 5 then
			tremove(searches, 1)
			tinsert(status_bars, tremove(status_bars, 1))
			tinsert(tables, tremove(tables, 1))
			search_index = 4
		end

		search.status_bar = status_bars[getn(searches)]
		search.status_bar:update_status(100, 100)
		search.status_bar:set_text('')

		search.table = tables[getn(searches)]
		search.table:SetSort(1, 2, 3, 4, 5, 6, 7, 8, 9)
		search.table:Reset()
		search.table:SetDatabase(search.records)

		update_search(getn(searches))
	end

	function public.previous_search()
		search_box:ClearFocus()
		update_search(search_index - 1)
		subtab = RESULTS
	end

	function public.next_search()
		search_box:ClearFocus()
		update_search(search_index + 1)
		subtab = RESULTS
	end
end

function public.close_settings()
	if settings_button.open then
		settings_button:Click()
	end
end

function private.update_continuation()
	if current_search.continuation then
		resume_button:Show()
		search_box:SetPoint('RIGHT', resume_button, 'LEFT', -4, 0)
	else
		resume_button:Hide()
		search_box:SetPoint('RIGHT', start_button, 'LEFT', -4, 0)
	end
end

function private.discard_continuation()
	scan.abort(search_scan_id)
	current_search.continuation = nil
	update_continuation()
end

function update_start_stop()
	if current_search.active then
		stop_button:Show()
		start_button:Hide()
	else
		start_button:Show()
		stop_button:Hide()
	end
end

function private.update_auto_buy_filter()
	if aux_auto_buy_filter ~= '' then
		local queries, error = aux_filter_util.queries(aux_auto_buy_filter)
		if queries then
			if getn(queries) > 1 then
				print 'Error: The automatic buyout filter does not support multi-queries'
			elseif size(queries[1].blizzard_query) > 0 then
				print 'Error: The automatic buyout filter does not support Blizzard filters'
			else
				auto_buy_validator = queries[1].validator
				auto_buy_filter_button.prettified = queries[1].prettified
				auto_buy_filter_button:SetChecked(true)
				return
			end
		else
			print('Invalid auto buy filter:', error)
		end
	end
	aux_auto_buy_filter = ''
end

function private.start_real_time_scan(query, search, continuation)

	local ignore_page
	if not search then
		search = current_search
		query.blizzard_query.first_page = tonumber(continuation) or 0
		query.blizzard_query.last_page = tonumber(continuation) or 0
		ignore_page = not tonumber(continuation)
	end

	local next_page
	local new_records = t
	search_scan_id = scan.start{
		type = 'list',
		queries = {query},
		auto_buy_validator = search.auto_buy_validator,
		on_scan_start = function()
			search.status_bar:update_status(99.99, 99.99)
			search.status_bar:set_text('Scanning last page ...')
		end,
		on_page_loaded = function(_, _, last_page)
			next_page = last_page
			if last_page == 0 then
				ignore_page = false
			end
		end,
		on_auction = function(auction_record, ctrl)
			if not ignore_page then
				if search.auto_buy then
					ctrl.suspend()
					place_bid('list', auction_record.index, auction_record.buyout_price, papply(ctrl.resume, true))
					thread(when, later(GetTime(), 10), ctrl.resume, false)
				else
					tinsert(new_records, auction_record)
				end
			end
		end,
		on_complete = function()
			local map = tt
			for _, record in search.records do
				map[record.sniping_signature] = record
			end
			for _, record in new_records do
				map[record.sniping_signature] = record
			end
			init[new_records] = temp-values(map)

			if getn(new_records) > 2000 then
				StaticPopup_Show('AUX_SEARCH_TABLE_FULL')
			else
				search.records = new_records
				search.table:SetDatabase(search.records)
			end

			query.blizzard_query.first_page = next_page
			query.blizzard_query.last_page = next_page
			start_real_time_scan(query, search)
		end,
		on_abort = function()
			search.status_bar:update_status(100, 100)
			search.status_bar:set_text('Scan paused')

			search.continuation = next_page or not ignore_page and query.blizzard_query.first_page or true

			if current_search == search then
				update_continuation()
			end

			search.active = false
			update_start_stop()
		end,
	}
end

function private.start_search(queries, continuation)
	local current_query, current_page, total_queries, start_query, start_page

	local search = current_search

	total_queries = getn(queries)

	if continuation then
		start_query, start_page = unpack(continuation)
		for i = 1, start_query - 1 do
			tremove(queries, 1)
		end
		queries[1].blizzard_query.first_page = (queries[1].blizzard_query.first_page or 0) + start_page - 1
		search.table:SetSelectedRecord()
	else
		start_query, start_page = 1, 1
	end


	search_scan_id = scan.start{
		type = 'list',
		queries = queries,
		auto_buy_validator = search.auto_buy_validator,
		on_scan_start = function()
			search.status_bar:update_status(0,0)
			if continuation then
				search.status_bar:set_text('Resuming scan...')
			else
				search.status_bar:set_text('Scanning auctions...')
			end
		end,
		on_page_loaded = function(_, total_scan_pages)
			current_page = current_page + 1
			total_scan_pages = total_scan_pages + (start_page - 1)
			total_scan_pages = max(total_scan_pages, 1)
			current_page = min(current_page, total_scan_pages)
			search.status_bar:update_status(100 * (current_query - 1) / getn(queries), 100 * (current_page - 1) / total_scan_pages)
			search.status_bar:set_text(format('Scanning %d / %d (Page %d / %d)', current_query, total_queries, current_page, total_scan_pages))
		end,
		on_page_scanned = function()
			search.table:SetDatabase()
		end,
		on_start_query = function(query)
			current_query = current_query and current_query + 1 or start_query
			current_page = current_page and 0 or start_page - 1
		end,
		on_auction = function(auction_record, ctrl)
			if search.auto_buy then
				ctrl.suspend()
				place_bid('list', auction_record.index, auction_record.buyout_price, papply(ctrl.resume, true))
				thread(when, later(GetTime(), 10), ctrl.resume, false)
			elseif getn(search.records) < 2000 then
				tinsert(search.records, auction_record)
				if getn(search.records) == 2000 then
					StaticPopup_Show('AUX_SEARCH_TABLE_FULL')
				end
			end
		end,
		on_complete = function()
			search.status_bar:update_status(100, 100)
			search.status_bar:set_text('Scan complete')

			if current_search == search and frame.results:IsVisible() and getn(search.records) == 0 then
				subtab = SAVED
			end

			search.active = false
			update_start_stop()
		end,
		on_abort = function()
			search.status_bar:update_status(100, 100)
			search.status_bar:set_text('Scan paused')

			if current_query then
				search.continuation = {current_query, current_page + 1}
			else
				search.continuation = {start_query, start_page}
			end
			if current_search == search then
				update_continuation()
			end

			search.active = false
			update_start_stop()
		end,
	}
end

function public.execute(resume, real_time)

	if resume then
		real_time = current_search.real_time
	elseif real_time == nil then
		real_time = real_time_button:GetChecked()
	end

	if resume then
		search_box:SetText(current_search.filter_string)
	end
	local filter_string = search_box:GetText()

	local queries, error = aux_filter_util.queries(filter_string)
	if not queries then
		print('Invalid filter:', error)
		return
	elseif real_time then
		if getn(queries) > 1 then
			print('Error: The real time mode does not support multi-queries')
			return
		elseif queries[1].blizzard_query.first_page or queries[1].blizzard_query.last_page then
			print('Error: The real time mode does not support page ranges')
			return
		end
	end

	search_box:ClearFocus()

	if resume then
		current_search.table:SetSelectedRecord()
	else
		if filter_string ~= current_search.filter_string or current_search.dummy then
			if current_search.dummy then
				current_search.filter_string = filter_string
				current_search.dummy = false
			else
				new_search(filter_string)
			end
			aux_search_tab_saved.new_recent_search(filter_string, join(map(copy(queries), function(filter) return filter.prettified end), ';'))
		else
			current_search.records = t
			current_search.table:SetDatabase(current_search.records)
			if current_search.real_time ~= real_time then
				current_search.table:Reset()
			end
		end
		current_search.real_time = real_time_button:GetChecked()
		current_search.auto_buy = auto_buy_button:GetChecked()
		current_search.auto_buy_validator = auto_buy_validator
	end

	local continuation = resume and current_search.continuation
	discard_continuation()
	current_search.active = true
	update_start_stop()

	subtab = RESULTS
	if real_time then
		start_real_time_scan(queries[1], nil, continuation)
	else
		for _, query in queries do
			query.blizzard_query.first_page = blizzard_page_index(first_page_input:GetText())
			query.blizzard_query.last_page = blizzard_page_index(last_page_input:GetText())
		end
		start_search(queries, continuation)
	end
end

function private.test(record)
	return function(index)
		local auction_info = info.auction(index)
		return auction_info and auction_info.search_signature == record.search_signature
	end
end

do
	local scan_id = 0
	local IDLE, SEARCHING, FOUND = t, t, t
	local state = IDLE
	local found_index

	function public.find_auction(record)
		local search = current_search

		if not search.table:ContainsRecord(record) or is_player(record.owner) then
			return
		end

		scan.abort(scan_id)
		state = SEARCHING
		scan_id = aux_scan_util.find(
			record,
			current_search.status_bar,
			function()
				state = IDLE
			end,
			function()
				state = IDLE
				search.table:RemoveAuctionRecord(record)
			end,
			function(index)
				if search.table:GetSelection() and search.table:GetSelection().record ~= record then
					return
				end

				state = FOUND
				found_index = index

				if not record.high_bidder then
					bid_button:SetScript('OnClick', function()
						if test(record)(index) and search.table:ContainsRecord(record) then
							place_bid('list', index, record.bid_price, record.bid_price < record.buyout_price and function()
								info.bid_update(record)
								search.table:SetDatabase()
							end or papply(search.table.RemoveAuctionRecord, search.table, record))
						end
					end)
					bid_button:Enable()
				end

				if record.buyout_price > 0 then
					buyout_button:SetScript('OnClick', function()
						if test(record)(index) and search.table:ContainsRecord(record) then
							place_bid('list', index, record.buyout_price, papply(search.table.RemoveAuctionRecord, search.table, record))
						end
					end)
					buyout_button:Enable()
				end
			end
		)
	end

	function private.on_update()
		if state == IDLE or state == SEARCHING then
			buyout_button:Disable()
			bid_button:Disable()
		end

		if state == SEARCHING then return end

		local selection = current_search.table:GetSelection()
		if not selection then
			state = IDLE
		elseif selection and state == IDLE then
			find_auction(selection.record)
		elseif state == FOUND and not test(selection.record)(found_index) then
			buyout_button:Disable()
			bid_button:Disable()
			if not bid_in_progress then
				state = IDLE
			end
		end
	end
end