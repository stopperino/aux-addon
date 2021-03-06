aux_search_tab_frame = module

local gui, completion, listing, auction_listing, filter_util = aux_gui, aux_completion, aux_listing, aux_auction_listing, aux_filter_util

local FILTER_SPACING = 28.5

function public.create()
	setfenv(1, getfenv(2))
	public.frame = CreateFrame('Frame', nil, AuxFrame)
	frame:SetAllPoints()
	frame:SetScript('OnUpdate', on_update)
	frame:Hide()

	frame.filter = gui.panel(frame)
	frame.filter:SetAllPoints(AuxFrame.content)

	frame.results = gui.panel(frame)
	frame.results:SetAllPoints(AuxFrame.content)

	frame.saved = CreateFrame('Frame', nil, frame)
	frame.saved:SetAllPoints(AuxFrame.content)

	frame.saved.favorite = gui.panel(frame.saved)
	frame.saved.favorite:SetWidth(378.5)
	frame.saved.favorite:SetPoint('TOPLEFT', 0, 0)
	frame.saved.favorite:SetPoint('BOTTOMLEFT', 0, 0)

	frame.saved.recent = gui.panel(frame.saved)
	frame.saved.recent:SetWidth(378.5)
	frame.saved.recent:SetPoint('TOPRIGHT', 0, 0)
	frame.saved.recent:SetPoint('BOTTOMRIGHT', 0, 0)
	do
	    local btn = gui.button(frame)
	    btn:SetPoint('TOPLEFT', 0, 0)
	    btn:SetWidth(42)
	    btn:SetHeight(42)
	    btn:SetScript('OnClick', function()
	        if this.open then
	            settings:Hide()
	            controls:Show()
	        else
	            settings:Show()
	            controls:Hide()
	        end
	        this.open = not this.open
	    end)

	    for _, offset in temp-A(14, 10, 6) do
	        local fake_icon_part = btn:CreateFontString()
	        fake_icon_part:SetFont([[Fonts\FRIZQT__.TTF]], 23)
	        fake_icon_part:SetPoint('CENTER', 0, offset)
	        fake_icon_part:SetText('_')
	    end

	    public.settings_button = btn
	end
	do
	    local panel = CreateFrame('Frame', nil, frame)
	    panel:SetBackdrop{bgFile=[[Interface\Buttons\WHITE8X8]]}
	    panel:SetBackdropColor(color.content.background())
	    panel:SetPoint('LEFT', settings_button, 'RIGHT', 0, 0)
	    panel:SetPoint('RIGHT', 0, 0)
	    panel:SetHeight(42)
	    panel:Hide()
	    public.settings = panel
	end
	do
	    local panel = CreateFrame('Frame', nil, frame)
	    panel:SetPoint('LEFT', settings_button, 'RIGHT', 0, 0)
	    panel:SetPoint('RIGHT', 0, 1)
	    panel:SetHeight(40)
	    public.controls = panel
	end
	do
		local function change()
			local page = tonumber(this:GetText())
			local valid_input = page and tostring(max(1, page)) or ''
			if this:GetText() ~= valid_input then
				this:SetText(valid_input)
			end
			if blizzard_page_index(this:GetText()) and not real_time_button:GetChecked() then
				this:SetBackdropColor(color.state.enabled())
			else
				this:SetBackdropColor(color.state.disabled())
			end
		end
		do
		    local editbox = gui.editbox(settings)
		    editbox:SetPoint('LEFT', 75, 0)
		    editbox:SetWidth(50)
		    editbox:SetNumeric(true)
		    editbox:SetScript('OnTabPressed', function() last_page_input:SetFocus() end)
		    editbox.enter = execute
		    editbox.change = change
		    local label = gui.label(editbox, 16)
		    label:SetPoint('RIGHT', editbox, 'LEFT', -6, 0)
		    label:SetText('Pages')
		    label:SetTextColor(color.text.enabled())
		    public.first_page_input = editbox
	    end
		do
		    local editbox = gui.editbox(settings)
		    editbox:SetPoint('LEFT', first_page_input, 'RIGHT', 10, 0)
		    editbox:SetWidth(50)
		    editbox:SetNumeric(true)
		    editbox:SetScript('OnTabPressed', function() first_page_input:SetFocus() end)
		    editbox.enter = execute
		    editbox.change = change
		    local label = gui.label(editbox, gui.font_size.medium)
		    label:SetPoint('RIGHT', editbox, 'LEFT', -3.5, 0)
		    label:SetText('-')
		    label:SetTextColor(color.text.enabled())
		    public.last_page_input = editbox
		end
	end
	do
	    local btn = gui.checkbutton(settings)
	    btn:SetPoint('LEFT', 230, 0)
	    btn:SetWidth(140)
	    btn:SetHeight(25)
	    btn:SetText('Real Time Mode')
	    btn:SetScript('OnClick', function()
	        this:SetChecked(not this:GetChecked())
	        this = first_page_input
	        first_page_input:GetScript('OnTextChanged')()
	        this = last_page_input
	        last_page_input:GetScript('OnTextChanged')()
	    end)
	    public.real_time_button = btn
	end
	do
	    local btn = gui.checkbutton(settings)
	    btn:SetPoint('LEFT', real_time_button, 'RIGHT', 15, 0)
	    btn:SetWidth(140)
	    btn:SetHeight(25)
	    btn:SetText('Auto Buyout Mode')
	    btn:SetScript('OnClick', function()
	        if this:GetChecked() then
	            this:SetChecked(false)
	        else
	            StaticPopup_Show('AUX_SEARCH_AUTO_BUY')
	        end
	    end)
	    public.auto_buy_button = btn
	end
	do
	    local btn = gui.checkbutton(settings)
	    btn:SetPoint('LEFT', auto_buy_button, 'RIGHT', 15, 0)
	    btn:SetWidth(140)
	    btn:SetHeight(25)
	    btn:SetText('Auto Buyout Filter')
	    btn:SetScript('OnClick', function()
	        if this:GetChecked() then
	            this:SetChecked(false)
	            aux_search_tab_results.aux_auto_buy_filter = nil
	            this.prettified = nil
	            aux_search_tab_results.auto_buy_validator = nil
	        else
	            StaticPopup_Show('AUX_SEARCH_AUTO_BUY_FILTER')
	        end
	    end)
	    btn:SetScript('OnEnter', function()
	        if this.prettified then
	            GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
	            GameTooltip:AddLine(gsub(this.prettified, ';', '\n\n'), 255/255, 254/255, 250/255, true)
	            GameTooltip:Show()
	        end
	    end)
	    btn:SetScript('OnLeave', function()
	        GameTooltip:Hide()
	    end)
	    public.auto_buy_filter_button = btn
	end
	do
	    local btn = gui.button(controls, 25)
	    btn:SetPoint('LEFT', 5, 0)
	    btn:SetWidth(30)
	    btn:SetHeight(25)
	    btn:SetText('<')
	    btn:SetScript('OnClick', aux_search_tab_results.previous_search)
	    public.previous_button = btn
	end
	do
	    local btn = gui.button(controls, 25)
	    btn:SetPoint('LEFT', previous_button, 'RIGHT', 4, 0)
	    btn:SetWidth(30)
	    btn:SetHeight(25)
	    btn:SetText('>')
	    btn:SetScript('OnClick', aux_search_tab_results.next_search)
	    public.next_button = btn
	end
	do
	    local btn = gui.button(controls, gui.font_size.huge)
	    btn:SetPoint('RIGHT', -5, 0)
	    btn:SetWidth(70)
	    btn:SetHeight(25)
	    btn:SetText('Start')
	    btn:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
	    btn:SetScript('OnClick', function()
	        if arg1 == 'RightButton' then
	            set_filter(aux_search_tab_results.current_search.filter_string)
	        end
	        execute()
	    end)
	    public.start_button = btn
	end
	do
	    local btn = gui.button(controls, gui.font_size.huge)
	    btn:SetPoint('RIGHT', -5, 0)
	    btn:SetWidth(70)
	    btn:SetHeight(25)
	    btn:SetText('Stop')
	    btn:SetScript('OnClick', function()
	        aux_scan.abort(aux_search_tab_results.search_scan_id)
	    end)
	    public.stop_button = btn
	end
	do
	    local btn = gui.button(controls, gui.font_size.huge)
	    btn:SetPoint('RIGHT', start_button, 'LEFT', -4, 0)
	    btn:SetWidth(70)
	    btn:SetHeight(25)
	    btn:SetText(color.green 'Resume')
	    btn:SetScript('OnClick', function()
	        execute(true)
	    end)
	    public.resume_button = btn
	end
	do
	    local editbox = gui.editbox(controls)
	    editbox:EnableMouse(1)
	    editbox.formatter = function(str)
		    local queries = aux_filter_util.queries(str)
		    return queries and join(map(copy(queries), function(query) return query.prettified end), ';') or color.red(str)
		end
	    editbox.complete = completion.complete_filter
	    editbox:SetPoint('RIGHT', start_button, 'LEFT', -4, 0)
	    editbox:SetHeight(25)
	    editbox.char = function()
	        this:complete()
	    end
	    editbox:SetScript('OnTabPressed', function()
	        this:HighlightText(0, 0)
	    end)
	    editbox.enter = execute
	    public.search_box = editbox
	end
	do
	    gui.horizontal_line(frame, -40)
	end
	do
	    local btn = gui.button(frame, gui.font_size.large)
	    btn:SetPoint('BOTTOMLEFT', AuxFrame.content, 'TOPLEFT', 10, 8)
	    btn:SetWidth(243)
	    btn:SetHeight(22)
	    btn:SetText('Search Results')
	    btn:SetScript('OnClick', function() subtab = RESULTS end)
	    public.search_results_button = btn
	end
	do
	    local btn = gui.button(frame, gui.font_size.large)
	    btn:SetPoint('TOPLEFT', search_results_button, 'TOPRIGHT', 5, 0)
	    btn:SetWidth(243)
	    btn:SetHeight(22)
	    btn:SetText('Saved Searches')
	    btn:SetScript('OnClick', function() subtab = SAVED end)
	    public.saved_searches_button = btn
	end
	do
	    local btn = gui.button(frame, gui.font_size.large)
	    btn:SetPoint('TOPLEFT', saved_searches_button, 'TOPRIGHT', 5, 0)
	    btn:SetWidth(243)
	    btn:SetHeight(22)
	    btn:SetText('Filter Builder')
	    btn:SetScript('OnClick', function() subtab = FILTER end)
	    public.new_filter_button = btn
	end
	do
	    local frame = CreateFrame('Frame', nil, frame)
	    frame:SetWidth(265)
	    frame:SetHeight(25)
	    frame:SetPoint('TOPLEFT', AuxFrame.content, 'BOTTOMLEFT', 0, -6)
	    public.status_bar_frame = frame
	end
	do
	    local btn = gui.button(frame.results)
	    btn:SetPoint('TOPLEFT', status_bar_frame, 'TOPRIGHT', 5, 0)
	    btn:SetText('Bid')
	    btn:Disable()
	    public.bid_button = btn
	end
	do
	    local btn = gui.button(frame.results)
	    btn:SetPoint('TOPLEFT', bid_button, 'TOPRIGHT', 5, 0)
	    btn:SetText('Buyout')
	    btn:Disable()
	    public.buyout_button = btn
	end
	do
	    local btn = gui.button(frame.results)
	    btn:SetPoint('TOPLEFT', buyout_button, 'TOPRIGHT', 5, 0)
	    btn:SetText('Clear')
	    btn:SetScript('OnClick', function()
	        while tremove(aux_search_tab_results.current_search.records) do end
	        aux_search_tab_results.current_search.table:SetDatabase()
	    end)
	end
	do
	    local btn = gui.button(frame.saved)
	    btn:SetPoint('TOPLEFT', status_bar_frame, 'TOPRIGHT', 5, 0)
	    btn:SetText('Favorite')
	    btn:SetScript('OnClick', function()
	        local queries, error = filter_util.queries(search_box:GetText())
	        if queries then
	            tinsert(_G.aux_favorite_searches, 1, T(
	                'filter_string', search_box:GetText(),
	                'prettified', join(map(queries, function(query) return query.prettified end), ';')
	            ))
	        else
		        print('Invalid filter:', error)
	        end
	        aux_search_tab_saved.update_search_listings()
	    end)
	end
	do
	    local btn1 = gui.button(frame.filter)
	    btn1:SetPoint('TOPLEFT', status_bar_frame, 'TOPRIGHT', 5, 0)
	    btn1:SetText('Search')
	    btn1:SetScript('OnClick', function()
		    aux_search_tab_filter.export_filter_string()
	        execute()
	    end)

	    local btn2 = gui.button(frame.filter)
	    btn2:SetPoint('LEFT', btn1, 'RIGHT', 5, 0)
	    btn2:SetText('Export')
	    btn2:SetScript('OnClick', aux_search_tab_filter.export_filter_string)

	    local btn3 = gui.button(frame.filter)
	    btn3:SetPoint('LEFT', btn2, 'RIGHT', 5, 0)
	    btn3:SetText('Import')
	    btn3:SetScript('OnClick', aux_search_tab_filter.import_filter_string)
	end
	do
	    local editbox = gui.editbox(frame.filter)
	    editbox.complete_item = completion.complete(function() return aux_auctionable_items end)
	    editbox:SetPoint('TOPLEFT', 14, -FILTER_SPACING)
	    editbox:SetWidth(260)
	    editbox.char = function()
	        if aux_search_tab_filter.blizzard_query.exact then
	            this:complete_item()
	        end
	    end
	    editbox:SetScript('OnTabPressed', function()
		    if aux_search_tab_filter.blizzard_query.exact then
			    return
		    end
	        if IsShiftKeyDown() then
	            max_level_input:SetFocus()
	        else
	            min_level_input:SetFocus()
	        end
	    end)
	    editbox.change = aux_search_tab_filter.update_form
	    editbox.enter = papply(editbox.ClearFocus, editbox)
	    local label = gui.label(editbox, gui.font_size.small)
	    label:SetPoint('BOTTOMLEFT', editbox, 'TOPLEFT', -2, 1)
	    label:SetText('Name')
	    public.name_input = editbox
	end
	do
	    local checkbox = gui.checkbox(frame.filter)
	    checkbox:SetPoint('TOPLEFT', name_input, 'TOPRIGHT', 16, 0)
	    checkbox:SetScript('OnClick', aux_search_tab_filter.update_form)
	    local label = gui.label(checkbox, gui.font_size.small)
	    label:SetPoint('BOTTOMLEFT', checkbox, 'TOPLEFT', -2, 1)
	    label:SetText('Exact')
	    public.exact_checkbox = checkbox
	end
	do
	    local editbox = gui.editbox(frame.filter)
	    editbox:SetPoint('TOPLEFT', name_input, 'BOTTOMLEFT', 0, -FILTER_SPACING)
	    editbox:SetWidth(125)
	    editbox:SetNumeric(true)
	    editbox:SetScript('OnTabPressed', function()
	        if IsShiftKeyDown() then
	            name_input:SetFocus()
	        else
	            max_level_input:SetFocus()
	        end
	    end)
	    editbox.enter = papply(editbox.ClearFocus, editbox)
	    editbox.change = function()
		    local valid_level = aux_search_tab_filter.valid_level(this:GetText())
		    if tostring(valid_level) ~= this:GetText() then
			    this:SetText(valid_level or '')
		    end
		    aux_search_tab_filter.update_form()
	    end
	    local label = gui.label(editbox, gui.font_size.small)
	    label:SetPoint('BOTTOMLEFT', editbox, 'TOPLEFT', -2, 1)
	    label:SetText('Level Range')
	    public.min_level_input = editbox
	end
	do
	    local editbox = gui.editbox(frame.filter)
	    editbox:SetPoint('TOPLEFT', min_level_input, 'TOPRIGHT', 10, 0)
	    editbox:SetWidth(125)
	    editbox:SetNumeric(true)
	    editbox:SetScript('OnTabPressed', function()
	        if IsShiftKeyDown() then
	            min_level_input:SetFocus()
	        else
	            name_input:SetFocus()
	        end
	    end)
	    editbox.enter = papply(editbox.ClearFocus, editbox)
	    editbox.change = function()
		    local valid_level = aux_search_tab_filter.valid_level(this:GetText())
		    if tostring(valid_level) ~= this:GetText() then
			    this:SetText(valid_level or '')
		    end
		    aux_search_tab_filter.update_form()
	    end
	    local label = gui.label(editbox, gui.font_size.medium)
	    label:SetPoint('RIGHT', editbox, 'LEFT', -3, 0)
	    label:SetText('-')
	    public.max_level_input = editbox
	end
	do
	    local checkbox = gui.checkbox(frame.filter)
	    checkbox:SetPoint('TOPLEFT', max_level_input, 'TOPRIGHT', 16, 0)
	    checkbox:SetScript('OnClick', aux_search_tab_filter.update_form)
	    local label = gui.label(checkbox, gui.font_size.small)
	    label:SetPoint('BOTTOMLEFT', checkbox, 'TOPLEFT', -2, 1)
	    label:SetText('Usable')
	    public.usable_checkbox = checkbox
	end
	do
	    local dropdown = gui.dropdown(frame.filter)
	    public.class_dropdown = dropdown
	    dropdown:SetPoint('TOPLEFT', min_level_input, 'BOTTOMLEFT', 0, 5 - FILTER_SPACING)
	    dropdown:SetWidth(300)
	    local label = gui.label(dropdown, gui.font_size.small)
	    label:SetPoint('BOTTOMLEFT', dropdown, 'TOPLEFT', -2, -3)
	    label:SetText('Item Class')
	    UIDropDownMenu_Initialize(dropdown, aux_search_tab_filter.initialize_class_dropdown)
	    dropdown:SetScript('OnShow', function()
	        UIDropDownMenu_Initialize(this, aux_search_tab_filter.initialize_class_dropdown)
	    end)
	end
	do
	    local dropdown = gui.dropdown(frame.filter)
	    public.subclass_dropdown = dropdown
	    dropdown:SetPoint('TOPLEFT', class_dropdown, 'BOTTOMLEFT', 0, 10 - FILTER_SPACING)
	    dropdown:SetWidth(300)
	    local label = gui.label(dropdown, gui.font_size.small)
	    label:SetPoint('BOTTOMLEFT', dropdown, 'TOPLEFT', -2, -3)
	    label:SetText('Item Subclass')
	    UIDropDownMenu_Initialize(dropdown, aux_search_tab_filter.initialize_subclass_dropdown)
	    dropdown:SetScript('OnShow', function()
	        UIDropDownMenu_Initialize(this, aux_search_tab_filter.initialize_subclass_dropdown)
	    end)
	end
	do
	    local dropdown = gui.dropdown(frame.filter)
	    public.slot_dropdown = dropdown
	    dropdown:SetPoint('TOPLEFT', subclass_dropdown, 'BOTTOMLEFT', 0, 10 - FILTER_SPACING)
	    dropdown:SetWidth(300)
	    local label = gui.label(dropdown, gui.font_size.small)
	    label:SetPoint('BOTTOMLEFT', dropdown, 'TOPLEFT', -2, -3)
	    label:SetText('Item Slot')
	    UIDropDownMenu_Initialize(dropdown, aux_search_tab_filter.initialize_slot_dropdown)
	    dropdown:SetScript('OnShow', function()
	        UIDropDownMenu_Initialize(this, aux_search_tab_filter.initialize_slot_dropdown)
	    end)
	end
	do
	    local dropdown = gui.dropdown(frame.filter)
	    public.quality_dropdown = dropdown
	    dropdown:SetPoint('TOPLEFT', slot_dropdown, 'BOTTOMLEFT', 0, 10 - FILTER_SPACING)
	    dropdown:SetWidth(300)
	    local label = gui.label(dropdown, gui.font_size.small)
	    label:SetPoint('BOTTOMLEFT', dropdown, 'TOPLEFT', -2, -3)
	    label:SetText('Min Quality')
	    UIDropDownMenu_Initialize(dropdown, aux_search_tab_filter.initialize_quality_dropdown)
	    dropdown:SetScript('OnShow', function()
	        UIDropDownMenu_Initialize(this, aux_search_tab_filter.initialize_quality_dropdown)
	    end)
	end
	gui.vertical_line(frame.filter, 332)
	do
	    local dropdown = gui.dropdown(frame.filter)
	    dropdown:SetPoint('TOPRIGHT', -174.5, -10)
	    dropdown:SetWidth(150)
	    UIDropDownMenu_Initialize(dropdown, aux_search_tab_filter.initialize_filter_dropdown)
	    dropdown:SetScript('OnShow', function()
	        UIDropDownMenu_Initialize(this, aux_search_tab_filter.initialize_filter_dropdown)
	    end)
	    _G[dropdown:GetName() .. 'Text']:Hide()
	    local label = gui.label(dropdown, gui.font_size.medium)
	    label:SetPoint('RIGHT', dropdown, 'LEFT', -15, 0)
	    label:SetText('Post Filter')
	    public.filter_dropdown = dropdown
	end
	do
		local input = gui.editbox(frame.filter)
		input:SetPoint('CENTER', filter_dropdown, 'CENTER', 0, 0)
		input:SetWidth(150)
		input:SetScript('OnTabPressed', function() filter_parameter_input:SetFocus() end)
		input.complete = completion.complete(function() return temp-A('and', 'or', 'not', unpack(keys(filter_util.filters))) end)
		input.char = function() this:complete() end
		input.change = function()
			local text = this:GetText()
			if filter_util.filters[text] and filter_util.filters[text].input_type ~= '' then
				local _, _, suggestions = filter_util.parse_filter_string(text .. '/')
				filter_parameter_input:SetNumeric(filter_util.filters[text].input_type == 'number')
				filter_parameter_input.complete = completion.complete(function() return suggestions or empty end)
				filter_parameter_input:Show()
			else
				filter_parameter_input:Hide()
			end
		end
		input.enter = function()
			if filter_parameter_input:IsVisible() then
				filter_parameter_input:SetFocus()
			else
				aux_search_tab_filter.add_post_filter()
			end
		end
		public.filter_input = input
	end
	do
	    local input = gui.editbox(frame.filter)
	    input:SetPoint('LEFT', filter_dropdown, 'RIGHT', 10, 0)
	    input:SetWidth(150)
	    input:SetScript('OnTabPressed', function()
		    filter_input:SetFocus()
	    end)
	    input.char = function() this:complete() end
	    input.enter = aux_search_tab_filter.add_post_filter
	    input:Hide()
	    public.filter_parameter_input = input
	end
	do
	    local scroll_frame = CreateFrame('ScrollFrame', nil, frame.filter)
	    scroll_frame:SetWidth(395)
	    scroll_frame:SetHeight(270)
	    scroll_frame:SetPoint('TOPLEFT', 348.5, -50)
	    scroll_frame:EnableMouse(true)
	    scroll_frame:EnableMouseWheel(true)
	    scroll_frame:SetScript('OnMouseWheel', function()
		    local child = this:GetScrollChild()
		    child:SetFont('p', [[Fonts\ARIALN.TTF]], bounded(11, 23, select(2, child:GetFont()) + arg1*2))
		    aux_search_tab_filter.update_filter_display()
	    end)
	    scroll_frame:RegisterForDrag('LeftButton')
	    scroll_frame:SetScript('OnDragStart', function()
		    this.x, this.y = GetCursorPosition()
		    this.x_offset, this.y_offset = this:GetHorizontalScroll(), this:GetVerticalScroll()
			this.x_extra, this.y_extra = 0, 0
		    this:SetScript('OnUpdate', function()
			    local x, y = GetCursorPosition()
			    local new_x_offset = this.x_offset + x - this.x
			    local new_y_offset = this.y_offset + y - this.y

			    aux_search_tab_filter.set_filter_display_offset(new_x_offset - this.x_extra, new_y_offset - this.y_extra)

			    this.x_extra = max(this.x_extra, new_x_offset)
			    this.y_extra = min(this.y_extra, new_y_offset)
		    end)
	    end)
	    scroll_frame:SetScript('OnDragStop', function()
		    this:SetScript('OnUpdate', nil)
	    end)
	    gui.set_content_style(scroll_frame, -2, -2, -2, -2)
	    local scroll_child = CreateFrame('SimpleHTML', nil, scroll_frame)
	    scroll_frame:SetScrollChild(scroll_child)
	    scroll_child:SetFont('p', [[Fonts\ARIALN.TTF]], 23)
	    scroll_child:SetTextColor('p', color.label.enabled())
	    scroll_child:SetWidth(1)
	    scroll_child:SetHeight(1)
	    scroll_child:SetScript('OnHyperlinkClick', aux_search_tab_filter.data_link_click)
--	    scroll_child:SetHyperlinkFormat("format") TODO
	    scroll_child.measure = scroll_child:CreateFontString()
	    public.filter_display = scroll_child
	end

	public.status_bars = t
	public.tables = t
	for _ = 1, 5  do
	    local status_bar = gui.status_bar(frame)
	    status_bar:SetAllPoints(status_bar_frame)
	    status_bar:Hide()
	    tinsert(status_bars, status_bar)

	    local table = auction_listing.CreateAuctionResultsTable(frame.results, auction_listing.search_config)
	    table:SetHandler('OnCellClick', function(cell, button)
	        if IsAltKeyDown() and aux_search_tab_results.current_search.table:GetSelection().record == cell.row.data.record then
	            if button == 'LeftButton' and buyout_button:IsEnabled() then
	                buyout_button:Click()
	            elseif button == 'RightButton' and bid_button:IsEnabled() then
	                bid_button:Click()
	            end
	        end
	    end)
	    table:SetHandler('OnSelectionChanged', function(rt, datum)
	        if not datum then return end
	        aux_search_tab_results.find_auction(datum.record)
	    end)
	    table:Hide()
	    tinsert(tables, table)
	end

	local handlers = {
	    OnClick = function(st, data, _, button)
	        if not data then return end
	        if button == 'LeftButton' and IsShiftKeyDown() then
	            search_box:SetText(data.search.filter_string)
	        elseif button == 'RightButton' and IsShiftKeyDown() then
	            add_filter(data.search.filter_string)
	        elseif button == 'LeftButton' and IsControlKeyDown() then
	            if st == favorite_searches_listing and data.index > 1 then
	                local temp = aux_favorite_searches[data.index - 1]
	                aux_favorite_searches[data.index - 1] = data.search
	                aux_favorite_searches[data.index] = temp
	                aux_search_tab_saved.update_search_listings()
	            end
	        elseif button == 'RightButton' and IsControlKeyDown() then
	            if st == favorite_searches_listing and data.index < getn(aux_favorite_searches) then
	                local temp = aux_favorite_searches[data.index + 1]
	                aux_favorite_searches[data.index + 1] = data.search
	                aux_favorite_searches[data.index] = temp
	                aux_search_tab_saved.update_search_listings()
	            end
	        elseif button == 'LeftButton' then
	            search_box:SetText(data.search.filter_string)
	            execute()
	        elseif button == 'RightButton' then
	            if st == recent_searches_listing then
	                tinsert(aux_favorite_searches, 1, data.search)
	            elseif st == favorite_searches_listing then
	                tremove(aux_favorite_searches, data.index)
	            end
	            aux_search_tab_saved.update_search_listings()
	        end
	    end,
	    OnEnter = function(st, data, self)
	        if not data then return end
	        GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
	        GameTooltip:AddLine(gsub(data.search.prettified, ';', '\n\n'), 255/255, 254/255, 250/255, true)
	        GameTooltip:Show()
	    end,
	    OnLeave = function()
	        GameTooltip:ClearLines()
	        GameTooltip:Hide()
	    end
	}

	public.recent_searches_listing = listing.CreateScrollingTable(frame.saved.recent)
	recent_searches_listing:SetColInfo{{ name='Recent Searches', width=1 }}
	recent_searches_listing:EnableSorting(false)
	recent_searches_listing:DisableSelection(true)
	recent_searches_listing:SetHandler('OnClick', handlers.OnClick)
	recent_searches_listing:SetHandler('OnEnter', handlers.OnEnter)
	recent_searches_listing:SetHandler('OnLeave', handlers.OnLeave)

	public.favorite_searches_listing = listing.CreateScrollingTable(frame.saved.favorite)
	favorite_searches_listing:SetColInfo{{ name='Favorite Searches', width=1 }}
	favorite_searches_listing:EnableSorting(false)
	favorite_searches_listing:DisableSelection(true)
	favorite_searches_listing:SetHandler('OnClick', handlers.OnClick)
	favorite_searches_listing:SetHandler('OnEnter', handlers.OnEnter)
	favorite_searches_listing:SetHandler('OnLeave', handlers.OnLeave)
end