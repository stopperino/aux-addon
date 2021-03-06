aux_auctions_tab = module

include (green_t)
include (aux)
include (aux_util)
include (aux_control)
include (aux_util_color)

TAB 'Auctions'

local scan = aux_scan

private.auction_records = t

function LOAD()
	aux_auctions_tab_frame.create()
end

function OPEN()
    frame:Show()
    scan_auctions()
end

function CLOSE()
    frame:Hide()
end

function private.update_listing()
    if not ACTIVE then return end
    listing:SetDatabase(auction_records)
end

function public.scan_auctions()

    status_bar:update_status(0,0)
    status_bar:set_text('Scanning auctions...')

    wipe(auction_records)
    update_listing()
    scan.start{
        type = 'owner',
        queries = {{ blizzard_query = t }},
        on_page_loaded = function(page, total_pages)
            status_bar:update_status(100 * (page - 1) / total_pages, 0)
            status_bar:set_text(format('Scanning (Page %d / %d)', page, total_pages))
        end,
        on_auction = function(auction_record)
            tinsert(auction_records, auction_record)
        end,
        on_complete = function()
            status_bar:update_status(100, 100)
            status_bar:set_text('Scan complete')
            update_listing()
        end,
        on_abort = function()
            status_bar:update_status(100, 100)
            status_bar:set_text('Scan aborted')
        end,
    }
end

function private.test(record)
    return function(index)
        local auction_info = aux_info.auction(index, 'owner')
        return auction_info and auction_info.search_signature == record.search_signature
    end
end

do
    local scan_id = 0
    local IDLE, SEARCHING, FOUND = t, t, t
    local state = IDLE
    local found_index

    function private.find_auction(record)
        if not listing:ContainsRecord(record) then return end

        scan.abort(scan_id)
        state = SEARCHING
        scan_id = aux_scan_util.find(
            record,
            status_bar,
            function() state = IDLE end,
            function() state = IDLE; listing:RemoveAuctionRecord(record) end,
            function(index)
                state = FOUND
                found_index = index

                cancel_button:SetScript('OnClick', function()
                    if test(record)(index) and listing:ContainsRecord(record) then
                        cancel_auction(index, papply(listing.RemoveAuctionRecord, listing, record))
                    end
                end)
                cancel_button:Enable()
            end
        )
    end

    function private.on_update()
        if state == IDLE or state == SEARCHING then
            cancel_button:Disable()
        end

        if state == SEARCHING then return end

        local selection = listing:GetSelection()
        if not selection then
            state = IDLE
        elseif selection and state == IDLE then
            find_auction(selection.record)
        elseif state == FOUND and not test(selection.record)(found_index) then
            cancel_button:Disable()
            if not cancel_in_progress then state = IDLE end
        end
    end
end