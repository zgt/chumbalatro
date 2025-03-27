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
    config = { extra = {mult_gain = 1.5 } },
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
                context.other_card.ability.perma_x_mult = math.max(context.other_card.ability.perma_x_mult, 1)
                context.other_card.ability.perma_x_mult = context.other_card.ability.perma_x_mult * card.ability.extra.mult_gain
                return {
                    extra = {message = localize('k_upgrade_ex'), colour = G.C.MULT},
                    colour = G.C.MULT,
                    card = card
                }
            end
        end
            
    end

}

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
		if not SMODS.has_no_suit(v) then -- Abstracted enhancement check for jokers being able to give cards additional enhancements
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