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
    rarity = 3,
    atlas = 'Chumbalatro',
    pos = { x = 1, y = 0},
    cost = 5,
    loc_vars = function(self, info_queue, card)
        local kc1 = G.GAME.current_round and G.GAME.current_round.kissing_card1 or { rank = "2" }
        local kc2 = G.GAME.current_round and G.GAME.current_round.kissing_card2 or { rank = "7" }
        return {
            vars = {
                localize(kc1.rank, "ranks"),
                localize(kc2.rank, "ranks"),
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
    rarity = 3,
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
			local other_joker
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
    rarity = 2,
    atlas = 'Chumbalatro',
    pos = { x = 2, y = 0},
    cost = 5,
    loc_vars = function(self, info_queue, card)
        local numerator, denominator = SMODS.get_probability_vars(card, 1, card.ability.extra.odds, 'contagion')
        return {
            vars = {
                numerator,
                denominator
            }
        }
    end,
    calculate = function(self,card,context)
        if context.individual and context.cardarea == G.play and context.scoring_name == 'High Card' and #context.full_hand > 1 then
            local leftmost = context.scoring_hand[1]
            for i = 2, #context.full_hand do
                if SMODS.pseudorandom_probability(card, 'contagion', 1, card.ability.extra.odds) then
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
            "converts random joker in your possession",
            "to {C:dark_edition}Negative"
        }
    },
    blueprint_compat = true,
    config = { extra = {} },
    rarity = 4,
    atlas = 'Chumbalatro',
    pos = { x = 4, y = 0},
    cost = 20,
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

SMODS.Joker {
    key = 'matryoshka',
    loc_txt = {
        name = 'Matryoshka',
        text = {
            "{X:mult,C:white} X#1# {} Mult",
            "When {C:attention}sold{}, a smaller",
            "doll pops out",
            "{C:inactive}(#2# dolls inside)"
        }
    },
    blueprint_compat = true,
    config = { extra = { x_mult = 3, dolls = 4 } },
    rarity = 3,
    atlas = 'Chumbalatro',
    pos = { x = 3, y = 0},
    cost = 8,
    loc_vars = function(self, info_queue, card)
        return {
            vars = {
                card.ability.extra.x_mult,
                card.ability.extra.dolls
            }
        }
    end,
    calculate = function(self, card, context)
        if context.joker_main then
            return {
                xmult = card.ability.extra.x_mult
            }
        end
        if context.selling_self and card.ability.extra.dolls > 0 then
            -- Each doll is half as far above X1 as its parent, at half the cost.
            local next_x = format_number(1 + (card.ability.extra.x_mult - 1) / 2, "%.4g")
            local next_dolls = card.ability.extra.dolls - 1
            local next_cost = math.max(1, math.floor((card.base_cost or self.cost) / 2))
            G.E_MANAGER:add_event(Event({trigger = 'after', delay = 0.3, func = function()
                local new_card = SMODS.add_card { key = 'j_chmb_matryoshka' }
                if new_card then
                    new_card.ability.extra.x_mult = next_x
                    new_card.ability.extra.dolls = next_dolls
                    new_card.base_cost = next_cost
                    new_card:set_cost()
                    new_card:juice_up(0.3, 0.5)
                    card_eval_status_text(new_card, 'extra', nil, nil, nil, { message = 'Pop!', colour = G.C.RED })
                end
                return true
            end}))
        end
    end
}

-- Big/to_big/to_number/is_number only exist when Talisman is installed;
-- fall back to plain numbers without it.
function format_number(number, str)
	local n = Big and to_number(to_big(number)) or number
	if math.abs(n) >= 1e300 then
		return number
	end
	return tonumber(str:format(n))
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
        local isnum = is_number or function(x) return type(x) == 'number' end
        local tbl = deep_copy(card[ref_val])
        for k, v in pairs(tbl) do
            if (type(tbl[k]) ~= "table") or isnum(tbl[k]) then
                if
                    isnum(tbl[k])
                    and not (k == "perish_tally")
                    and not (k == "id")
                    and not (k == "colour")
                    and not (k == "suit_nominal")
                    and not (k == "base_nominal")
                    and not (k == "face_nominal")
                    and not (k == "qty")
                    and not (k == "x_mult" and v == 1 and not tbl.override_x_mult_check)
                    and not (k == "selected_d6_face")
                    and not (k == "card_limit")
                    and not (k == "extra_slots_used")
                    and not (k == "dolls")
                then
                    if k == "odds" then
                        -- Denominator of a "1 in N" chance: divide so the
                        -- probability improves; 1 in 1 is the best possible.
                        tbl[k] = math.max(1, format_number(tbl[k] / value, "%.2g"))
                    else
                        tbl[k] = format_number(tbl[k] * value, "%.2g")
                    end
                end
            else
                for _k, _v in pairs(tbl[k]) do
                    if
                        isnum(tbl[k][_k])
                        and not (_k == "id")
                        and not (k == "colour")
                        and not (_k == "suit_nominal")
                        and not (_k == "base_nominal")
                        and not (_k == "face_nominal")
                        and not (_k == "qty")
                        and not (k == "x_mult" and v == 1 and not tbl[k].override_x_mult_check)
                        and not (_k == "selected_d6_face")
                        and not (_k == "card_limit")
                        and not (_k == "extra_slots_used")
                        and not (_k == "dolls")
                    then --Refer to above
                        if _k == "odds" then
                            tbl[k][_k] = math.max(1, format_number(tbl[k][_k] / value, "%.2g"))
                        else
                            tbl[k][_k] = format_number(tbl[k][_k] * value, "%.2g")
                        end
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

-- Rerolls the kissing cards at run start and every round (SMODS calls this
-- at Game:start_run and alongside reset_castle_card).
SMODS.current_mod.reset_game_globals = function(run_start)
	G.GAME.current_round.kissing_card1 = { rank = "2" }
	G.GAME.current_round.kissing_card2 = { rank = "7" }
	local valid_kissing_cards = {}
	for _, v in ipairs(G.playing_cards) do
		if v.ability.effect ~= 'Stone Card' then
			valid_kissing_cards[#valid_kissing_cards + 1] = v
		end
	end
	if valid_kissing_cards[1] then
		local kissing_card_1 = pseudorandom_element(valid_kissing_cards, pseudoseed("kiss1" .. G.GAME.round_resets.ante))
		-- Only cards of a different rank are valid partners; if the whole deck
		-- is one rank there is no second card and the defaults stay.
		local partner_cards = {}
		for _, v in ipairs(valid_kissing_cards) do
			if v.base.value ~= kissing_card_1.base.value then
				partner_cards[#partner_cards + 1] = v
			end
		end
		if partner_cards[1] then
			local kissing_card_2 = pseudorandom_element(partner_cards, pseudoseed("kiss2" .. G.GAME.round_resets.ante))
			G.GAME.current_round.kissing_card1.rank = kissing_card_1.base.value
			G.GAME.current_round.kissing_card1.id = kissing_card_1.base.id
			G.GAME.current_round.kissing_card2.rank = kissing_card_2.base.value
			G.GAME.current_round.kissing_card2.id = kissing_card_2.base.id
		end
	end
end