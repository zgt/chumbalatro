SMODS.Atlas {
    key="Chumbalatro",
    path="Chumbalatro.png",
    px = 71,
    py = 95
}

SMODS.Joker {
    key = 'kissing',
    loc_txt = {
        name = 'Big Kiss',
        text = {
            "If hand contains a {C:attention}#1#{} and {C:attention}#2#",
            "multiply both cards current mult by {X:mult,C:white} X#3# {}"
        }
    },
    blueprint_compat = true,
    config = { extra = {mult_gain = 1.1 } },
    rarity = 1,
    atlas = 'Chumbalatro',
    pos = { x = 1, y = 0},
    cost = 5,
    loc_vars = function(self, info_queue, card)
        return {
            vars = {
                localize(G.GAME.current_round.kissing_card1.rank, "ranks"),
                localize(G.GAME.current_round.kissing_card2.rank, "ranks"),
                card.ability.extra.mult_gain
            }
        }
    end,
    calculate = function(self,card,context)
        local has_card1 = false
        local has_card2 = false
        if context.individual and context.cardarea == G.play and context.full_hand then
            for i = 1, #context.full_hand do
                if context.full_hand[i]:get_id() == G.GAME.current_round.kissing_card1.id then
                    has_card1 = true
                elseif context.full_hand[i]:get_id() == G.GAME.current_round.kissing_card2.id then
                    has_card2 = true
                end
            end
            if has_card1 and has_card2 then
                if context.other_card.base.id == G.GAME.current_round.kissing_card1.id or context.other_card.base.id == G.GAME.current_round.kissing_card2.id then 
                    if context.other_card.ability.perma_x_mult == 0 then
                        context.other_card.ability.perma_x_mult = math.max(context.other_card.ability.perma_x_mult, 1)
                    end
                    context.other_card.ability.perma_x_mult = context.other_card.ability.perma_x_mult * card.ability.extra.mult_gain
                    return {
                        extra = {message = localize('k_upgrade_ex'), colour = G.C.MULT},
                        colour = G.C.MULT,
                        card = card
                    }
                end
            end
        end
    end
}

SMODS.Joker {
    key = 'snowball',
    loc_txt = {
        name = 'Snowball',
        text = {
            "Increase values of {C:attention}Joker{} to the right",
			"by {C:attention}X#1#{} at end of round",
        }
    },
    blueprint_compat = true,
    config = { extra = {increase = 1.2} },
    rarity = 1,
    atlas = 'Chumbalatro',
    pos = { x = 0, y = 0},
    cost = 5,
    loc_vars = function(self, info_queue, card)
        card.ability.blueprint_compat_ui = card.ability.blueprint_compat_ui or ""
		card.ability.blueprint_compat_check = nil
		return {
			vars = { card.ability.extra.increase },
			main_end = (card.area and card.area == G.jokers) and {
				{
					n = G.UIT.C,
					config = { align = "bm", minh = 0.4 },
					nodes = {
						{
							n = G.UIT.C,
							config = {
								ref_table = card,
								align = "m",
								colour = G.C.JOKER_GREY,
								r = 0.05,
								padding = 0.06,
								func = "blueprint_compat",
							},
							nodes = {
								{
									n = G.UIT.T,
									config = {
										ref_table = card.ability,
										ref_value = "blueprint_compat_ui",
										colour = G.C.UI.TEXT_LIGHT,
										scale = 0.32 * 0.8,
									},
								},
							},
						},
					},
				},
			} or nil,
		}
	end,
    update = function(self, card, front)
		if G.STAGE == G.STAGES.RUN then
			for i = 1, #G.jokers.cards do
				if G.jokers.cards[i] == card then
					other_joker = G.jokers.cards[i + 1]
				end
			end
			if other_joker and other_joker ~= card then
				card.ability.blueprint_compat = "compatible"
			else
				card.ability.blueprint_compat = "incompatible"
			end
		end
	end,
    calculate = function(self, card, context)
		if context.end_of_round and not context.repetition and not context.individual then
			local check = false
			for i = 1, #G.jokers.cards do
				if G.jokers.cards[i] == card then
					if i < #G.jokers.cards then
                        check = true
                        with_deck_effects(G.jokers.cards[i + 1], function(cards)
                            multiply_values(cards, card.ability.extra.increase)
                        end)
					end
				end
			end
			if check then
				card_eval_status_text(
					card,
					"extra",
					nil,
					nil,
					nil,
					{ message = localize("k_upgrade_ex"), colour = G.C.GREEN }
				)
			end
		end
	end
}

SMODS.Joker {
    key = 'contagion',
    loc_txt = {
        name = 'Contagion',
        text = {
            "When you play a {C:attention}high card,",
            "non-scoring cards have a {C:green,E:1,S:1.1}#1# in #2#{}",
            "chance to be converted to the scoring card"
        }
    },
    blueprint_compat = true,
    config = { extra = {odds = 4} },
    rarity = 1,
    atlas = 'Chumbalatro',
    pos = { x = 2, y = 0},
    cost = 5,
    loc_vars = function(self, info_queue, card)
        return {
            vars = {
                (G.GAME.probabilities.normal or 1),
                card.ability.extra.odds
            }
        }
    end,
    calculate = function(self,card,context)
        if context.individual and context.cardarea == G.play and context.scoring_name == 'High Card' and #context.full_hand > 1 then
            local leftmost = context.scoring_hand[1]
            for i = 2, #context.full_hand do
                if pseudorandom('contagion') < G.GAME.probabilities.normal / card.ability.extra.odds then
                    G.E_MANAGER:add_event(Event({trigger = 'after',delay = 0.1,func = function()
                        if context.full_hand[i] ~= leftmost then
                            copy_card(leftmost, context.full_hand[i])
                            context.full_hand[i]:juice_up(0.3, 0.3)
                        end
                        return true end }))
                    card_eval_status_text(
                        context.full_hand[i],
                        'extra',
                        nil,
					    nil,
					    nil,
                        { message = "Converted!"}
                    )
                end
            end
            
        end
    end
}

SMODS.Joker {
    key = 'lucretia',
    loc_txt = {
        name = 'Lucretia',
        text = {
            "After defeating the {C:attention}boss blind,",
            "converts random joker in your posession",
            "to {C:dark_edition}Negative"
        }
    },
    blueprint_compat = true,
    config = { extra = {} },
    rarity = 1,
    atlas = 'Chumbalatro',
    pos = { x = 0, y = 0},
    cost = 5,
    loc_vars = function(self, info_queue, card)
        return {
            vars = {
            }
        }
    end,
    calculate = function(self,card,context)
        if context.end_of_round and G.GAME.blind.boss and context.cardarea == G.jokers then
            local jokers = {}
            for i=1, #G.jokers.cards do 
                if G.jokers.cards[i] ~= card and not G.jokers.cards[i].edition then
                    jokers[#jokers+1] = G.jokers.cards[i]
                end
            end
            if #jokers > 0 then 
                G.E_MANAGER:add_event(Event({trigger = 'after', delay = 0.4, func = function()
                    local chosen_joker = pseudorandom_element(jokers, pseudoseed('lucretia'))
                    local messageText = chosen_joker.label .. ' Negative!'
                    card_eval_status_text(context.blueprint_card or card, 'extra', nil, nil, nil, {message = messageText})
                    chosen_joker:set_edition('e_negative', true)
                    card:juice_up(0.3, 0.5)
                return true end}))
            end
        end
    end
}

function format_number(number, str)
	if math.abs(to_big(number)) >= to_big(1e300) then
		return number
	end
	return tonumber(str:format((Big and to_number(to_big(number)) or number)))
end

function with_deck_effects(card, func)
	if not card.added_to_deck then
		return func(card)
	else
		card:remove_from_deck(true)
		local ret = func(card)
		card:add_to_deck(true)
		return ret
	end
end

function multiply_values(card, value)
    local key = card.config.center_key
    local ref_val = "ability"
    if key and card and ref_val then
        tbl = deep_copy(card[ref_val])
        for k, v in pairs(tbl) do
            if (type(tbl[k]) ~= "table") or is_number(tbl[k]) then
                if
                    is_number(tbl[k])
                    and not (k == "perish_tally")
                    and not (k == "id")
                    and not (k == "colour")
                    and not (k == "suit_nominal")
                    and not (k == "base_nominal")
                    and not (k == "face_nominal")
                    and not (k == "qty")
                    and not (k == "x_mult" and v == 1 and not tbl.override_x_mult_check)
                    and not (k == "selected_d6_face")
                then 
                    tbl[k] = format_number(tbl[k] * value, "%.2g")
                end
            else
                for _k, _v in pairs(tbl[k]) do
                    if
                        is_number(tbl[k][_k])
                        and not (_k == "id")
                        and not (k == "colour")
                        and not (_k == "suit_nominal")
                        and not (_k == "base_nominal")
                        and not (_k == "face_nominal")
                        and not (_k == "qty")
                        and not (k == "x_mult" and v == 1 and not tbl[k].override_x_mult_check)
                        and not (_k == "selected_d6_face")
                    then --Refer to above
                        tbl[k][_k] = format_number(tbl[k][_k] * value, "%.2g")
                    end
                end
            end
        end
        card[ref_val] = tbl
    end
end

function deep_copy(obj, seen)
    if type(obj) ~= "table" then
		return obj
	end
	if seen and seen[obj] then
		return seen[obj]
	end
	local s = seen or {}
	local res = setmetatable({}, getmetatable(obj))
	s[obj] = res
	for k, v in pairs(obj) do
		res[deep_copy(k, s)] = deep_copy(v, s)
	end
	return res
end

local gigo = Game.init_game_object
function Game:init_game_object()
	local g = gigo(self)
	g.current_round.kissing_card1 = { rank = "2"}
    g.current_round.kissing_card2 = { rank = "7"}
	return g
end

local rcc = reset_castle_card
-- This is a part 2 of the above thing, to make the custom G.GAME variable change every round.
function reset_castle_card()
    rcc()
	-- The suit changes every round, so we use reset_game_globals to choose a suit.
	G.GAME.current_round.kissing_card1 = { rank = "2"}
    G.GAME.current_round.kissing_card2 = { rank = "7"}
	local valid_castle_cards = {}
	for _, v in ipairs(G.playing_cards) do
		if v.ability.effect ~= 'Stone Card' then -- Abstracted enhancement check for jokers being able to give cards additional enhancements
			valid_castle_cards[#valid_castle_cards + 1] = v
		end
	end
	if valid_castle_cards[1] then
        --Kissing Cards
        local kissing_card_1 = pseudorandom_element(valid_castle_cards, pseudoseed("kiss1" .. G.GAME.round_resets.ante))
        local kissing_card_2 = pseudorandom_element(valid_castle_cards, pseudoseed("kiss2" .. G.GAME.round_resets.ante))
        if not G.GAME.current_round.kissing_card1 then
			G.GAME.current_round.kissing_card1 = {}
		end
        if not G.GAME.current_round.kissing_card2 then
			G.GAME.current_round.kissing_card2 = {}
		end
        print(kissing_card_1.base.value)
        print(kissing_card_2.base.value)
        while kissing_card_1.base.value == kissing_card_2.base.value do
            kissing_card_2 = pseudorandom_element(valid_castle_cards, pseudoseed("kiss2" .. G.GAME.round_resets.ante))
            print(kissing_card_2.base.value)
        end
        G.GAME.current_round.kissing_card1.rank = kissing_card_1.base.value
		G.GAME.current_round.kissing_card1.id = kissing_card_1.base.id

        G.GAME.current_round.kissing_card2.rank = kissing_card_2.base.value
		G.GAME.current_round.kissing_card2.id = kissing_card_2.base.id

	end
end

-- Back.apply_to_run Hook for decks
local Backapply_to_runRef = Back.apply_to_run
function Back.apply_to_run(self)
	Backapply_to_runRef(self)
	if self.effect.config.cry_no_edition_price then
		G.GAME.modifiers.cry_no_edition_price = true
	end
end

--Game:update hook
local upd = Game.update