aux_search_tab = module

include (green_t)
include (aux)
include (aux_util)
include (aux_control)
include (aux_util_color)

TAB 'Search'

StaticPopupDialogs.AUX_SEARCH_TABLE_FULL = {
    text = 'Table full!\nFurther results from this search will still be processed but no longer displayed in the table.',
    button1 = 'Ok',
    showAlert = 1,
    timeout = 0,
    hideOnEscape = 1,
}
StaticPopupDialogs.AUX_SEARCH_AUTO_BUY = {
    text = 'Are you sure you want to activate automatic buyout?',
    button1 = 'Yes',
    button2 = 'No',
    OnAccept = function()
        auto_buy_button:SetChecked(true)
    end,
    timeout = 0,
    hideOnEscape = 1,
}

public.RESULTS = 1
public.SAVED = 2
public.FILTER = 3

function LOAD()
	aux_search_tab_frame.create()
	subtab = SAVED
end

function OPEN()
    frame:Show()
    aux_search_tab_saved.update_search_listings()
end

function CLOSE()
	aux_search_tab_results.close_settings()
    aux_search_tab_results.current_search.table:SetSelectedRecord()
    frame:Hide()
end

function CLICK_LINK(item_info)
	set_filter(strlower(item_info.name) .. '/exact')
	execute(nil, false)
end

function USE_ITEM(item_info)
	set_filter(strlower(item_info.name) .. '/exact')
	execute(nil, false)
end

function public.execute(resume, real_time)
	aux_search_tab_results.execute(resume, real_time)
end

function public.subtab.set(tab)
    search_results_button:UnlockHighlight()
    saved_searches_button:UnlockHighlight()
    new_filter_button:UnlockHighlight()
    frame.results:Hide()
    frame.saved:Hide()
    frame.filter:Hide()

    if tab == RESULTS then
        frame.results:Show()
        search_results_button:LockHighlight()
    elseif tab == SAVED then
        frame.saved:Show()
        saved_searches_button:LockHighlight()
    elseif tab == FILTER then
        frame.filter:Show()
        new_filter_button:LockHighlight()
    end
end

function public.set_filter(filter_string)
    search_box:SetText(filter_string)
end

function public.add_filter(filter_string)
    local old_filter_string = search_box:GetText()
    old_filter_string = trim(old_filter_string)

    if old_filter_string ~= '' then
        old_filter_string = old_filter_string .. ';'
    end

    search_box:SetText(old_filter_string .. filter_string)
end

function public.blizzard_page_index(str)
    if tonumber(str) then
        return max(0, tonumber(str) - 1)
    end
end

