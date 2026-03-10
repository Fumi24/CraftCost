local addonName = ...

local function HasPriceAddon()
    return TSM_API ~= nil
        or (Auctionator and Auctionator.API and Auctionator.API.v1) ~= nil
        or RECrystallize_PriceCheckItemID ~= nil
        or OEMarketInfo ~= nil
end

local function GetItemPrice(itemID)
    if not itemID then return 0 end

    if not HasPriceAddon() then
        print("|cff00ccffCraftCost:|r No price addon detected. Install TSM, Auctionator, RECrystallize, or OribosExchange for accurate costs.")
    end

    if TSM_API then
        local itemString = "i:" .. itemID
        local price = TSM_API.GetCustomPriceValue("min(DBMinBuyout,VendorBuy)", itemString)
        if price and price > 0 then return price end
        price = TSM_API.GetCustomPriceValue("VendorBuy", itemString)
        if price and price > 0 then return price end
    end

    if Auctionator and Auctionator.API and Auctionator.API.v1 then
        local price = Auctionator.API.v1.GetVendorPriceByItemID(addonName, itemID)
        if price and price > 0 then return price end
        price = Auctionator.API.v1.GetAuctionPriceByItemID(addonName, itemID)
        if price and price > 0 then return price end
    end

    if RECrystallize_PriceCheckItemID then
        local price = RECrystallize_PriceCheckItemID(itemID)
        if price and price > 0 then return price end
    end

    if OEMarketInfo then
        local result = {}
        OEMarketInfo(itemID, result)
        local price = (result.market and result.market > 0 and result.market)
                   or (result.region and result.region > 0 and result.region)
        if price then return price end
    end

    local vendorPrice = select(11, GetItemInfo(itemID))
    if vendorPrice and vendorPrice > 0 then return vendorPrice end

    return 0
end

local function CalcRecipeCost(recipeID, isRecraft)
    local schematic = C_TradeSkillUI.GetRecipeSchematic(recipeID, isRecraft or false)
    if not schematic then return nil end

    local totalCost = 0
    local anyUnknown = false

    for _, slot in ipairs(schematic.reagentSlotSchematics) do
        if slot.required then
            local qty = slot.quantityRequired
            if qty and qty > 0 then
                local cheapest = nil
                for _, reagent in ipairs(slot.reagents) do
                    if reagent.itemID then
                        local price = GetItemPrice(reagent.itemID)
                        if price > 0 then
                            if cheapest == nil or price < cheapest then
                                cheapest = price
                            end
                        end
                    end
                end

                if cheapest then
                    totalCost = totalCost + cheapest * qty
                else
                    anyUnknown = true
                end
            end
        end
    end

    return totalCost, anyUnknown
end

local costLabel

local function UpdateCostLabel(recipeID, isRecraft)
    if not costLabel then return end

    if not recipeID then
        costLabel:SetText("")
        return
    end

    local totalCost, anyUnknown = CalcRecipeCost(recipeID, isRecraft)

    if not totalCost then
        costLabel:SetText("")
        return
    end

    local text
    if totalCost == 0 and anyUnknown then
        text = "Craft Cost: |cffff4444Unknown|r"
    elseif anyUnknown then
        text = "Craft Cost: " .. GetCoinTextureString(totalCost) .. " |cffff4444(+ unknown)|r"
    else
        text = "Craft Cost: " .. GetCoinTextureString(totalCost)
    end

    costLabel:SetText(text)
end

EventUtil.ContinueOnAddOnLoaded("CraftCost", function()
    if not HasPriceAddon() then
        print("|cff00ccffCraftCost:|r No price addon detected. Install TSM, Auctionator, RECrystallize, or OribosExchange for accurate costs.")
    end
end)

EventUtil.ContinueOnAddOnLoaded("Blizzard_Professions", function()
    local craftingPage = ProfessionsFrame.CraftingPage
    local schematicForm = craftingPage and craftingPage.SchematicForm
    if not schematicForm then return end

    costLabel = craftingPage:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    costLabel:SetPoint("BOTTOMLEFT", schematicForm, "BOTTOMLEFT", 10, -20)
    costLabel:SetJustifyH("LEFT")
    costLabel:SetText("")

    hooksecurefunc(schematicForm, "Init", function(self, recipeInfo)
        if not recipeInfo then
            UpdateCostLabel(nil)
            return
        end
        local recipeID = recipeInfo.recipeID
        local isRecraft = false
        local tx = self.GetTransaction and self:GetTransaction()
        if tx and tx.GetRecraftAllocation then
            isRecraft = tx:GetRecraftAllocation() ~= nil
        end
        UpdateCostLabel(recipeID, isRecraft)
    end)
end)