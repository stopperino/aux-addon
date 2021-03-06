aux_stack = module

include (green_t)
include (aux)
include (aux_util)
include (aux_control)
include (aux_util_color)

local info = aux_info

local state

function private.stack_size(slot)
    local container_item_info = info.container_item(unpack(slot))
    return container_item_info and container_item_info.count or 0
end

function private.charges(slot)
    local container_item_info = info.container_item(unpack(slot))
	return container_item_info and container_item_info.charges
end

function private.max_stack(slot)
	local container_item_info = info.container_item(unpack(slot))
	return container_item_info and container_item_info.max_stack
end

function private.locked(slot)
	local container_item_info = info.container_item(unpack(slot))
	return container_item_info and container_item_info.locked
end

function private.find_item_slot(papply)
	for slot in info.inventory do
		if matching_item(slot, papply) and not eq(slot, state.target_slot) then
			return slot
		end
	end
end

function private.matching_item(slot, papply)
	local item_info = info.container_item(unpack(slot))
	return item_info and item_info.item_key == state.item_key and info.auctionable(item_info.tooltip) and (not papply or item_info.count < item_info.max_stack)
end

function private.find_empty_slot()
	for slot, type in info.inventory do
		if type == 1 and not GetContainerItemInfo(unpack(slot)) then
			return slot
		end
	end
end

function private.find_charge_item_slot()
	for slot in info.inventory do
		if matching_item(slot) and charges(slot) == state.target_size then
			return slot
		end
	end
end

function private.move_item(from_slot, to_slot, amount, k)
	if locked(from_slot) or locked(to_slot) then
		return wait(k)
	end

	amount = min(max_stack(from_slot) - stack_size(to_slot), stack_size(from_slot), amount)
	local expected_size = stack_size(to_slot) + amount

	ClearCursor()
	SplitContainerItem(from_slot[1], from_slot[2], amount)
	PickupContainerItem(unpack(to_slot))

	return when(function() return stack_size(to_slot) == expected_size end, k)
end

function private.process()
	if not state.target_slot or not matching_item(state.target_slot) then
		state.target_slot = find_item_slot()
		if not state.target_slot then
			return stop()
		end
	end
	if charges(state.target_slot) then
		state.target_slot = find_charge_item_slot()
		return stop()
	end
	if stack_size(state.target_slot) > state.target_size then
		local slot = find_item_slot(true) or find_empty_slot()
		if slot then
			return move_item(
				state.target_slot,
				slot,
				stack_size(state.target_slot) - state.target_size,
				process
			)
		end
	elseif stack_size(state.target_slot) < state.target_size then
		local slot = find_item_slot()
		if slot then
			return move_item(
				slot,
				state.target_slot,
				state.target_size - stack_size(state.target_slot),
				process
			)
		end
	end
	return stop()
end

function public.stop()
	if state then
		kill_thread(state.thread_id)
		local callback, slot = state.callback, state.target_slot
		slot = slot and matching_item(slot) and slot or nil
		state = nil
		do (callback or nop)(slot) end
	end
end

function public.start(item_key, size, callback)
	stop()
	state = {
		thread_id = thread(process),
		item_key = item_key,
		target_size = size,
		callback = callback,
	}
end