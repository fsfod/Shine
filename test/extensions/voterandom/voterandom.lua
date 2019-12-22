--[[
	Shuffling logic tests.
]]

local UnitTest = Shine.UnitTest

local VoteShuffle = UnitTest:LoadExtension( "voterandom" )
if not VoteShuffle or not VoteShuffle.Config then return end

local MockShuffle = UnitTest.MockOf( VoteShuffle )

VoteShuffle.Config.IgnoreCommanders = false

local StringFormat = string.format
local TableSort = table.sort

UnitTest:Test( "AssignPlayers", function( Assert )
	local TeamMembers = {
		{
			1, 2, 3
		},
		{
			4, 5, 6
		}
	}

	local TeamSkills = {
		{
			Average = 1000,
			Total = 3000,
			Count = 3
		},
		{
			Average = 750,
			Total = 2250,
			Count = 3
		}
	}

	local SortTable = { 1, 2 }
	local Skills = { 1500, 1000 }

	local Count, NumTargets = 2, 2

	VoteShuffle:AssignPlayers( TeamMembers, SortTable, Count, NumTargets, TeamSkills, function( Player, TeamNumber )
		return Skills[ Player ]
	end )

	-- Should place 1500 player on lower skill team.
	Assert:Equals( 3750, TeamSkills[ 2 ].Total )
	Assert:Equals( 4, TeamSkills[ 2 ].Count )
	Assert:Equals( 3750 / 4, TeamSkills[ 2 ].Average )

	Assert:Equals( 4000, TeamSkills[ 1 ].Total )
	Assert:Equals( 4, TeamSkills[ 1 ].Count )
	Assert:Equals( 4000 / 4, TeamSkills[ 1 ].Average )
end, nil, 100 )

UnitTest:Test( "NormaliseSkills", function( Assert )
	local ScoreTable = {
		{
			Player = 4, Skill = 1.5
		},
		{
			Player = 5, Skill = 3
		},
		{
			Player = 6, Skill = 2
		}
	}

	VoteShuffle:NormaliseSkills( ScoreTable, 3 )

	local NormalisedScoreFactor = VoteShuffle.NormalisedScoreFactor

	Assert:Equals( NormalisedScoreFactor * 0.5, ScoreTable[ 4 ] )
	Assert:Equals( NormalisedScoreFactor, ScoreTable[ 5 ] )
	Assert:Equals( NormalisedScoreFactor / 3 * 2, ScoreTable[ 6 ] )
end )

UnitTest:Test( "AddPlayersRandomly", function( Assert )
	local TeamMembers = {
		{
			1
		},
		{
			2, 3, 4
		}
	}
	local Targets = { 5, 6, 7, 8 }

	VoteShuffle:AddPlayersRandomly( Targets, #Targets, TeamMembers )
	Assert:Equals( 4, #TeamMembers[ 1 ] )
	Assert:Equals( 4, #TeamMembers[ 2 ] )

	TeamMembers = {
		{
			1
		},
		{
			2, 3, 4
		}
	}
	Targets = { 5, 6 }

	VoteShuffle:AddPlayersRandomly( Targets, #Targets, TeamMembers )
	Assert:Equals( 3, #TeamMembers[ 1 ] )
	Assert:Equals( 3, #TeamMembers[ 2 ] )
end )

UnitTest:Test( "GetOptimalTeamForPlayer - Uneven teams", function( Assert )
	local Team1Players = { 1000, 1000, 1000, 1000, 1500 }
	local Team2Players = { 1000, 1000, 1000, 1000, 1000 }

	local function SkillGetter( Player ) return Player end

	local TeamToJoin = VoteShuffle:GetOptimalTeamForPlayer( 2000, Team1Players, Team2Players, SkillGetter )
	Assert.Equals( "Should pick team 2 as the optimal team", 2, TeamToJoin )
end )

UnitTest:Test( "GetOptimalTeamForPlayer - Even teams", function( Assert )
	local Team1Players = { 1000, 1000, 1000, 1000, 1000 }
	local Team2Players = { 1000, 1000, 1000, 1000, 1000 }

	local function SkillGetter( Player ) return Player end

	local TeamToJoin = VoteShuffle:GetOptimalTeamForPlayer( 2000, Team1Players, Team2Players, SkillGetter )
	Assert.Nil( "Should not pick an optimal team, both are equivalent", TeamToJoin )
end )

UnitTest:Test( "GetOptimalTeamForPlayer - Empty teams", function( Assert )
	local Team1Players = {}
	local Team2Players = {}

	local function SkillGetter( Player ) return Player end

	local TeamToJoin = VoteShuffle:GetOptimalTeamForPlayer( 2000, Team1Players, Team2Players, SkillGetter )
	Assert.Nil( "Should not pick an optimal team, both are empty", TeamToJoin )
end )

local function FakePlayer( SteamID, TeamNumber, IsCommander )
	return {
		GetClient = function()
			return {
				GetUserId = function() return SteamID end
			}
		end,
		GetTeamNumber = function() return TeamNumber end,
		isa = function( self, Type )
			if Type == "Commander" and IsCommander then
				return true
			end
			return false
		end
	}
end

VoteShuffle.HappinessHistory = {}
VoteShuffle.SaveHappinessHistory = function() end
VoteShuffle.HasShuffledThisRound = false

local FakeGamerules = {}
local BalanceModule = VoteShuffle.Modules[ #VoteShuffle.Modules - 3 ]

UnitTest:Test( "BalanceModule:EndGame - Does nothing if not shuffled", function( Assert )
	BalanceModule.EndGame( VoteShuffle, FakeGamerules, nil, { FakePlayer( 1 ) } )
	Assert:Equals( 0, #VoteShuffle.HappinessHistory )
end )

VoteShuffle.HasShuffledThisRound = true
VoteShuffle.LastShufflePreferences = nil

UnitTest:Test( "BalanceModule:EndGame - Does nothing if no preference stored", function( Assert )
	BalanceModule.EndGame( VoteShuffle, FakeGamerules, nil, { FakePlayer( 1 ) } )
	Assert:Equals( 0, #VoteShuffle.HappinessHistory )
end )

FakeGamerules.gameStartTime = Shared.GetTime()
UnitTest:Test( "BalanceModule:EndGame - Does nothing if round is too short", function( Assert )
	BalanceModule.EndGame( VoteShuffle, FakeGamerules, nil, { FakePlayer( 1 ) } )
	Assert:Equals( 0, #VoteShuffle.HappinessHistory )
end )

FakeGamerules.gameStartTime = -math.huge

VoteShuffle.LastShufflePreferences = {
	[ 1 ] = 1,
	[ 2 ] = 2
}
VoteShuffle.LastShuffleTeamLookup = {
	[ 1 ] = 1,
	[ 2 ] = 1,
	[ 3 ] = 2
}
UnitTest:Test( "BalanceModule:EndGame - Remembers team preferences", function( Assert )
	BalanceModule.EndGame( VoteShuffle, FakeGamerules, nil, { FakePlayer( 1, 1 ), FakePlayer( 2, 1 ), FakePlayer( 3, 2 ) } )
	-- Should store the round.
	Assert:Equals( 1, #VoteShuffle.HappinessHistory )
	-- Should remember that player 1 was on the team they wanted, while player 2 was not.
	-- Player 3 has no preference so they should not be stored.
	Assert:TableEquals( {
		[ "1" ] = true,
		[ "2" ] = false
	}, VoteShuffle.HappinessHistory[ 1 ] )
end )

VoteShuffle.HappinessHistory = {
	{
		[ "1" ] = true,
		[ "2" ] = false
	},
	{
		[ "1" ] = true,
		[ "2" ] = false,
		[ "3" ] = true
	},
	{
		[ "3" ] = false
	}
}

UnitTest:Test( "GetHistoricHappinessWeight", function( Assert )
	-- Two rounds, both on the preferred team, so should be a low weight.
	Assert:Equals( 0.25, VoteShuffle:GetHistoricHappinessWeight( FakePlayer( 1 ) ) )
	-- Two rounds, both on the non-preferred team, so should be a high weight.
	Assert:Equals( 4, VoteShuffle:GetHistoricHappinessWeight( FakePlayer( 2 ) ) )
	-- Two rounds, one on the preferred team and the other not, so should be weight 1.
	Assert:Equals( 1, VoteShuffle:GetHistoricHappinessWeight( FakePlayer( 3 ) ) )
end )

VoteShuffle.GetHistoricHappinessWeight = function( self, Player )
	return 1
end

UnitTest:Test( "OptimiseHappiness - More unhappiness swaps teams", function( Assert )
	local TeamMembers = {
		{ FakePlayer( 1 ), FakePlayer( 2 ) },
		{ FakePlayer( 3 ), FakePlayer( 4 ) },
	}
	local Team1 = TeamMembers[ 1 ]
	local Team2 = TeamMembers[ 2 ]
	TeamMembers.TeamPreferences = {
		-- Player 1 is unhappy
		[ Team1[ 1 ] ] = 2,
		-- Player 2 is happy
		[ Team1[ 2 ] ] = 1,
		-- Player 3 is unhappy
		[ Team2[ 1 ] ] = 1
		-- Player 4 is neutral
	}

	Assert:Equals( -1, VoteShuffle:OptimiseHappiness( TeamMembers ) )
	Assert:Equals( Team2, TeamMembers[ 1 ] )
	Assert:Equals( Team1, TeamMembers[ 2 ] )
	Assert:TableEquals( {
		[ 1 ] = 2,
		[ 2 ] = 1,
		[ 3 ] = 1
	}, VoteShuffle.LastShufflePreferences )
end )

UnitTest:Test( "OptimiseHappiness - Less unhappiness does nothing", function( Assert )
	local TeamMembers = {
		{ FakePlayer( 1 ), FakePlayer( 2 ) },
		{ FakePlayer( 3 ), FakePlayer( 4 ) },
	}
	local Team1 = TeamMembers[ 1 ]
	local Team2 = TeamMembers[ 2 ]
	TeamMembers.TeamPreferences = {
		-- Player 1 is happy
		[ Team1[ 1 ] ] = 1,
		-- Player 2 is happy
		[ Team1[ 2 ] ] = 1,
		-- Player 3 is unhappy
		[ Team2[ 1 ] ] = 1
		-- Player 4 is neutral
	}

	Assert:Equals( 1, VoteShuffle:OptimiseHappiness( TeamMembers ) )
	Assert:Equals( Team1, TeamMembers[ 1 ] )
	Assert:Equals( Team2, TeamMembers[ 2 ] )
	Assert:TableEquals( {
		[ 1 ] = 1,
		[ 2 ] = 1,
		[ 3 ] = 1
	}, VoteShuffle.LastShufflePreferences )
end )

UnitTest:Test( "ShouldOptimiseHappiness - Not ignoring commanders accepts optimisation", function( Assert )
	local TeamMembers = {
		{ FakePlayer( 1 ), FakePlayer( 2 ) },
		{ FakePlayer( 3 ), FakePlayer( 4, 2, true ) }
	}
	-- Can optimise with commanders
	Assert:True( VoteShuffle:ShouldOptimiseHappiness( TeamMembers ) )
	TeamMembers = {
		{ FakePlayer( 1 ), FakePlayer( 2 ) },
		{ FakePlayer( 3 ), FakePlayer( 4 ) }
	}
	-- Can optimise without commanders
	Assert:True( VoteShuffle:ShouldOptimiseHappiness( TeamMembers ) )
end )

VoteShuffle.Config.IgnoreCommanders = true

UnitTest:Test( "ShouldOptimiseHappiness - Ignoring commanders and having commanders rejects optimisation",
function( Assert )
	local TeamMembers = {
		{ FakePlayer( 1 ), FakePlayer( 2 ) },
		{ FakePlayer( 3 ), FakePlayer( 4, 2, true ) }
	}
	-- Cannot optimise when asked to ignore commanders and there are commanders present
	Assert:False( VoteShuffle:ShouldOptimiseHappiness( TeamMembers ) )
end )

UnitTest:Test( "ShouldOptimiseHappiness - Ignoring commanders and not having commanders accepts optimisation",
function( Assert )
	local TeamMembers = {
		{ FakePlayer( 1 ), FakePlayer( 2 ) },
		{ FakePlayer( 3 ), FakePlayer( 4 ) }
	}
	-- Can optimise when asked to ignore commanders but there are no commanders present
	Assert:True( VoteShuffle:ShouldOptimiseHappiness( TeamMembers ) )
end )

local VoteConstraints = {
	MinPlayers = 10,
	FractionNeededToPass = 0.75,
	MinPlayerFractionToConstrainSkillDiff = 0.9,
	MinAverageDiffToAllowShuffle = 100,
	MinStandardDeviationDiffToAllowShuffle = 0
}
function MockShuffle:GetCurrentVoteConstraints()
	return VoteConstraints
end

function MockShuffle:GetPlayerCountForVote()
	return 20
end

UnitTest:Test( "GetVotesNeeded - Returns current constraint fraction * number of players", function( Assert )
	Assert.Equals( "Should return player count * fraction", 15, MockShuffle:GetVotesNeeded() )
end )

UnitTest:Test( "IsRoundActive - Returns true if the game state is for an active round with no grace time", function( Assert )
	MockShuffle.InGameStateChangeTime = false

	local States = { "Countdown", "Started" }
	for i = 1, #States do
		Assert.True(
			StringFormat( "Should return true for the %s state", States[ i ] ),
			MockShuffle:IsRoundActive( kGameState[ States[ i ] ] )
		)
	end
end )

UnitTest:Test( "IsRoundActive - Returns true if the game state is for an active round and grace time has expired", function( Assert )
	MockShuffle.InGameStateChangeTime = Shared.GetTime() - 60

	local States = { "Countdown", "Started" }
	for i = 1, #States do
		Assert.True(
			StringFormat( "Should return true for the %s state", States[ i ] ),
			MockShuffle:IsRoundActive( kGameState[ States[ i ] ] )
		)
	end
end )

UnitTest:Test( "IsRoundActive - Returns true if the game state is for an active round and grace time has not expired but is ignored", function( Assert )
	MockShuffle.InGameStateChangeTime = Shared.GetTime() + 60

	local States = { "Countdown", "Started" }
	for i = 1, #States do
		Assert.True(
			StringFormat( "Should return true for the %s state", States[ i ] ),
			MockShuffle:IsRoundActive( kGameState[ States[ i ] ], true )
		)
	end
end )

UnitTest:Test( "IsRoundActive - Returns false if the game state is for an active round but grace time has not expired", function( Assert )
	MockShuffle.InGameStateChangeTime = Shared.GetTime() + 60

	local States = { "Countdown", "Started" }
	for i = 1, #States do
		Assert.False(
			StringFormat( "Should return false for the %s state", States[ i ] ),
			MockShuffle:IsRoundActive( kGameState[ States[ i ] ] )
		)
	end
end )

UnitTest:Test( "IsRoundActive - Returns false if the game state is for an inactive round", function( Assert )
	local States = { "NotStarted", "PreGame", "WarmUp", "Team1Won", "Team2Won", "Draw" }
	for i = 1, #States do
		Assert.False(
			StringFormat( "Should return false for the %s state", States[ i ] ),
			MockShuffle:IsRoundActive( kGameState[ States[ i ] ] )
		)
	end
end )

UnitTest:Test( "EvaluateConstraints - Number of players too low", function( Assert )
	Assert.True( "Should allow voting as only 2/10 players are on teams",
		MockShuffle:EvaluateConstraints( 10, {
			{ Skills = { 1000 } },
			{ Skills = { 1000 } }
		} )
	)
end )

UnitTest:Test( "EvaluateConstraints - Teams imbalanced", function( Assert )
	Assert.True( "Should allow voting as teams are imbalanced",
		MockShuffle:EvaluateConstraints( 4, {
			{ Skills = { 1000, 2000, 2000 } },
			{ Skills = { 1000 } }
		} )
	)
end )

UnitTest:Test( "EvaluateConstraints - Average diff is high enough", function( Assert )
	Assert.True( "Should allow voting as averages are too far apart",
		MockShuffle:EvaluateConstraints( 4, {
			{ Skills = { 1000, 2000 }, Average = 1500 },
			{ Skills = { 1000, 4000 }, Average = 2500 }
		} )
	)
end )

UnitTest:Test( "EvaluateConstraints - Min standard deviation difference = 0 is ignored", function( Assert )
	Assert.False( "Should ignore standard deviation as min is 0",
		MockShuffle:EvaluateConstraints( 4, {
			{ Skills = { 1500, 1500 }, Average = 1500, StandardDeviation = 0 },
			{ Skills = { 1000, 2000 }, Average = 1500, StandardDeviation = 500 }
		} )
	)
end )

UnitTest:Test( "EvaluateConstraints - Standard deviation diff is high enough", function( Assert )
	VoteConstraints.MinStandardDeviationDiffToAllowShuffle = 200

	Assert.True( "Should allow voting as standard deviations are too far apart",
		MockShuffle:EvaluateConstraints( 4, {
			{ Skills = { 1500, 1500 }, Average = 1500, StandardDeviation = 0 },
			{ Skills = { 1000, 2000 }, Average = 1500, StandardDeviation = 500 }
		} )
	)
end )

UnitTest:Test( "EvaluateConstraints - Teams are balanced", function( Assert )
	VoteConstraints.MinStandardDeviationDiffToAllowShuffle = 200

	Assert.False( "Should deny voting when teams are sufficiently balanced",
		MockShuffle:EvaluateConstraints( 4, {
			{ Skills = { 1500, 1500 }, Average = 1500, StandardDeviation = 0 },
			{ Skills = { 1500, 1500 }, Average = 1500, StandardDeviation = 0 }
		} )
	)
end )

UnitTest:Test( "GetTeamStats - Uses cached data if available", function( Assert )
	local RankFunc = function() end
	local Stats = {}

	MockShuffle.TeamStatsCache[ RankFunc ] = Stats
	local ComputedStats = MockShuffle:GetTeamStats( RankFunc )

	Assert.Equals( "Expected GetTeamStats to return cached data when available",
		Stats, ComputedStats )
end )

VoteShuffle.Config.IgnoreCommanders = false

UnitTest:Test( "RandomisePlayers - Keeps commanders on the same team", function( Assert )
	local Players = {}
	for i = 1, 5 do
		Players[ i ] = FakePlayer( i )
	end
	local Commanders = { FakePlayer( 6 ), FakePlayer( 7 ) }

	local TeamMembers = VoteShuffle:RandomisePlayers( Players, Commanders )
	Assert.Equals( "Should make team 1 have size 3", 3, #TeamMembers[ 1 ] )
	Assert.Equals( "Should make team 2 have size 4", 4, #TeamMembers[ 2 ] )
	Assert.Equals( "Should keep commander for team 1 on team 1", Commanders[ 1 ], TeamMembers[ 1 ][ 1 ] )
	Assert.Equals( "Should keep commander for team 2 on team 2", Commanders[ 2 ], TeamMembers[ 2 ][ 1 ] )
end )

UnitTest:Test( "RandomisePlayers - Keeps team sizes correct with only team 1 commander", function( Assert )
	local Players = {}
	for i = 1, 5 do
		Players[ i ] = FakePlayer( i )
	end
	local Commanders = { FakePlayer( 6 ) }

	local TeamMembers = VoteShuffle:RandomisePlayers( Players, Commanders )
	Assert.Equals( "Should make team 1 have size 3", 3, #TeamMembers[ 1 ] )
	Assert.Equals( "Should make team 2 have size 3", 3, #TeamMembers[ 2 ] )
	Assert.Equals( "Should keep commander for team 1 on team 1", Commanders[ 1 ], TeamMembers[ 1 ][ 1 ] )
end )

UnitTest:Test( "RandomisePlayers - Keeps team sizes correct with only team 1 commander and even number of non-commanders", function( Assert )
	local Players = {}
	for i = 1, 6 do
		Players[ i ] = FakePlayer( i )
	end
	local Commanders = { FakePlayer( 6 ) }

	local TeamMembers = VoteShuffle:RandomisePlayers( Players, Commanders )
	Assert.Equals( "Should make team 1 have size 4", 4, #TeamMembers[ 1 ] )
	Assert.Equals( "Should make team 2 have size 3", 3, #TeamMembers[ 2 ] )
	Assert.Equals( "Should keep commander for team 1 on team 1", Commanders[ 1 ], TeamMembers[ 1 ][ 1 ] )
end )

UnitTest:Test( "RandomisePlayers - Keeps team sizes correct with only team 2 commander", function( Assert )
	local Players = {}
	for i = 1, 5 do
		Players[ i ] = FakePlayer( i )
	end
	local Commanders = { nil, FakePlayer( 6 ) }

	local TeamMembers = VoteShuffle:RandomisePlayers( Players, Commanders )
	Assert.Equals( "Should make team 1 have size 3", 3, #TeamMembers[ 1 ] )
	Assert.Equals( "Should make team 2 have size 3", 3, #TeamMembers[ 2 ] )
	Assert.Equals( "Should keep commander for team 2 on team 2", Commanders[ 2 ], TeamMembers[ 2 ][ 1 ] )
end )

UnitTest:Test( "RandomisePlayers - Keeps team sizes correct with only team 2 commander and even number of non-commanders", function( Assert )
	local Players = {}
	for i = 1, 6 do
		Players[ i ] = FakePlayer( i )
	end
	local Commanders = { nil, FakePlayer( 6 ) }

	local TeamMembers = VoteShuffle:RandomisePlayers( Players, Commanders )
	Assert.Equals( "Should make team 1 have size 3", 3, #TeamMembers[ 1 ] )
	Assert.Equals( "Should make team 2 have size 4", 4, #TeamMembers[ 2 ] )
	Assert.Equals( "Should keep commander for team 2 on team 2", Commanders[ 2 ], TeamMembers[ 2 ][ 1 ] )
end )

UnitTest:Test( "RandomisePlayers - Keeps team sizes correct with no commanders", function( Assert )
	local Players = {}
	for i = 1, 5 do
		Players[ i ] = FakePlayer( i )
	end
	local Commanders = {}

	local TeamMembers = VoteShuffle:RandomisePlayers( Players, Commanders )
	Assert.Equals( "Should make team 1 have size 2", 2, #TeamMembers[ 1 ] )
	Assert.Equals( "Should make team 2 have size 3", 3, #TeamMembers[ 2 ] )
end )

UnitTest:Test( "RandomisePlayers - Keeps team sizes correct with even number of non-commanders", function( Assert )
	local Players = {}
	for i = 1, 6 do
		Players[ i ] = FakePlayer( i )
	end
	local Commanders = {}

	local TeamMembers = VoteShuffle:RandomisePlayers( Players, Commanders )
	Assert.Equals( "Should make team 1 have size 3", 3, #TeamMembers[ 1 ] )
	Assert.Equals( "Should make team 2 have size 3", 3, #TeamMembers[ 2 ] )
end )

UnitTest:Test( "FilterPlayerGroupsToTeamMembers - Removes players not in the team members only", function( Assert )
	local TeamMembers = {
		{
			FakePlayer( 1 ),
			FakePlayer( 2 )
		},
		{
			FakePlayer( 3 ),
			FakePlayer( 4 ),
			FakePlayer( 5 )
		}
	}
	local PlayerGroups = {
		{
			Players = {
				TeamMembers[ 2 ][ 3 ],
				FakePlayer( 6 )
			}
		},
		{
			Players = {
				TeamMembers[ 1 ][ 1 ],
				TeamMembers[ 1 ][ 2 ],
				FakePlayer( 7 )
			}
		}
	}

	local FilteredGroups = VoteShuffle:FilterPlayerGroupsToTeamMembers( PlayerGroups, TeamMembers )
	Assert.DeepEquals( "Should remove the first group and remove the 3rd player of the second group", {
		{
			Players = {
				TeamMembers[ 1 ][ 1 ],
				TeamMembers[ 1 ][ 2 ]
			}
		}
	}, FilteredGroups )
end )

VoteShuffle.SaveHappinessHistory = BalanceModule.SaveHappinessHistory
VoteShuffle.GetHistoricHappinessWeight = BalanceModule.GetHistoricHappinessWeight

UnitTest:Test( "ConsolidateGroupTeamPreferences", function( Assert )
	local Players = {}
	for i = 1, 10 do
		Players[ i ] = FakePlayer()
	end
	local TeamMembers = {
		TeamPreferences = {
			1,
			1,
			2,

			2,
			2,

			1,
			2,

			2,
			2,
			1
		}
	}
	for i = 1, #TeamMembers.TeamPreferences do
		TeamMembers.TeamPreferences[ Players[ i ] ] = TeamMembers.TeamPreferences[ i ]
		TeamMembers.TeamPreferences[ i ] = nil
	end

	local PlayerGroups = {
		{
			Players = {
				Players[ 1 ], Players[ 2 ], Players[ 3 ]
			}
		},
		{
			Players = {
				Players[ 4 ], Players[ 5 ]
			}
		},
		{
			Players = {
				Players[ 6 ], Players[ 7 ]
			}
		},
		{
			Players = {
				Players[ 8 ], Players[ 9 ], Players[ 10 ]
			}
		}
	}

	local TeamPrefs = {}
	VoteShuffle:ConsolidateGroupTeamPreferences( TeamMembers, PlayerGroups, function( Player, Client, Preference )
		TeamPrefs[ Player ] = Preference
	end )

	for i = 1, 3 do
		Assert.Equals( "First group should prefer team 1", 1, TeamPrefs[ Players[ i ] ] )
	end

	for i = 4, 5 do
		Assert.Equals( "Second group should prefer team 2", 2, TeamPrefs[ Players[ i ] ] )
	end

	Assert.Nil( "Third group should remove preferences", TeamPrefs[ Players[ 6 ] ] )
	Assert.Nil( "Third group should remove preferences", TeamPrefs[ Players[ 7 ] ] )

	for i = 8, 10 do
		Assert.Equals( "Fourth group should prefer team 2", 2, TeamPrefs[ Players[ i ] ] )
	end
end )

do
	local Clients = {}
	local function MockClient( SteamID )
		local Client = Clients[ SteamID ]
		if not Client then
			Client = UnitTest.MakeMockClient( SteamID )
			Clients[ SteamID ] = Client
		end
		return Client
	end

	local MockPlugin
	local function MakeMockPlugin()
		local ExistingFriendGroup = {
			Clients = {
				MockClient( 12345 ),
				MockClient( 54321 ),
				MockClient( 67890 )
			},
			Leader = MockClient( 12345 )
		}
		return setmetatable( {
			SendNetworkMessage = function() end,
			SendTranslatedError = function() end,
			SendTranslatedNotify = function() end,
			SendTranslatedNotification = function() end,
			FriendGroupsBySteamID = {
				[ 12345 ] = ExistingFriendGroup,
				[ 54321 ] = ExistingFriendGroup,
				[ 67890 ] = ExistingFriendGroup
			},
			FriendGroupInvitesBySteamID = {},
			FriendGroupInviteDelaysBySteamID = {},
			FriendGroupConfigBySteamID = setmetatable( {
				[ 789 ] = {
					LeaderType = VoteShuffle.FriendGroupLeaderType.ALLOW_ALL_TO_JOIN,
					JoinType = VoteShuffle.FriendGroupJoinType.BLOCK
				}
			}, {
				__index = function( self, Key )
					return {
						LeaderType = VoteShuffle.FriendGroupLeaderType.ALLOW_ALL_TO_JOIN,
						JoinType = VoteShuffle.FriendGroupJoinType.ALLOW_ALL
					}
				end
			} ),
			FriendGroups = {
				ExistingFriendGroup
			},
			Logger = {
				IsDebugEnabled = function() return false end,
				Debug = function() end
			},
			Config = {
				TeamPreferences = {
					MaxFriendGroupSize = 4,
					FriendGroupInviteDurationInSeconds = 30,
					FriendGroupInviteCooldownInSeconds = 30
				}
			}
		}, { __index = VoteShuffle } )
	end

	UnitTest:Before( function()
		MockPlugin = MakeMockPlugin()
	end )

	UnitTest:Test( "HandleFriendGroupJoinRequest - Client that's opted out is not added", function( Assert )
		VoteShuffle.HandleFriendGroupJoinRequest( MockPlugin, MockClient( 123 ), MockClient( 789 ) )

		Assert:Equals( 1, #MockPlugin.FriendGroups )
		Assert:ArrayContainsExactly(
			{ MockClient( 12345 ), MockClient( 54321 ), MockClient( 67890 ) },
			MockPlugin.FriendGroups[ 1 ].Clients
		)
		Assert:Equals( MockPlugin.FriendGroups[ 1 ], MockPlugin.FriendGroupsBySteamID[ 12345 ] )
		Assert:Equals( MockPlugin.FriendGroups[ 1 ], MockPlugin.FriendGroupsBySteamID[ 54321 ] )
		Assert.Nil( "Should not have added the target to a group", MockPlugin.FriendGroupsBySteamID[ 789 ] )
	end )

	UnitTest:Test( "HandleFriendGroupJoinRequest - Client that requires an invite is invited", function( Assert )
		MockPlugin.FriendGroupConfigBySteamID[ 789 ] = {
			LeaderType = VoteShuffle.FriendGroupLeaderType.ALLOW_ALL_TO_JOIN,
			JoinType = VoteShuffle.FriendGroupJoinType.REQUIRE_INVITE
		}
		VoteShuffle.HandleFriendGroupJoinRequest( MockPlugin, MockClient( 123 ), MockClient( 789 ) )

		Assert:Equals( 1, #MockPlugin.FriendGroups )
		Assert:ArrayContainsExactly(
			{ MockClient( 12345 ), MockClient( 54321 ), MockClient( 67890 ) },
			MockPlugin.FriendGroups[ 1 ].Clients
		)
		Assert.Nil( "Should not have added the target to a group", MockPlugin.FriendGroupsBySteamID[ 789 ] )

		local Invite = MockPlugin.FriendGroupInvitesBySteamID[ 789 ]
		Assert.NotNil( "Should have added an invite for the target player", Invite )
		Assert.Equals( "Should be invited by the calling client", 123, Invite.InviterID )

		local Delay = MockPlugin.FriendGroupInviteDelaysBySteamID[ 789 ]
		Assert.NotNil( "Should have added a delay for the next invite from the calling player to the target",
			Delay and Delay[ 123 ] )
	end )

	UnitTest:Test( "HandleFriendGroupJoinRequest - Client that requires an invite is rejected if already invited to another group", function( Assert )
		MockPlugin.FriendGroupConfigBySteamID[ 789 ] = {
			LeaderType = VoteShuffle.FriendGroupLeaderType.ALLOW_ALL_TO_JOIN,
			JoinType = VoteShuffle.FriendGroupJoinType.REQUIRE_INVITE
		}
		MockPlugin.FriendGroupInvitesBySteamID[ 789 ] = {
			InviterID = 12345,
			ExpiryTime = math.huge
		}
		VoteShuffle.HandleFriendGroupJoinRequest( MockPlugin, MockClient( 123 ), MockClient( 789 ) )

		Assert:Equals( 1, #MockPlugin.FriendGroups )
		Assert:ArrayContainsExactly(
			{ MockClient( 12345 ), MockClient( 54321 ), MockClient( 67890 ) },
			MockPlugin.FriendGroups[ 1 ].Clients
		)
		Assert.Nil( "Should not have added the target to a group", MockPlugin.FriendGroupsBySteamID[ 789 ] )

		local Invite = MockPlugin.FriendGroupInvitesBySteamID[ 789 ]
		Assert.Equals( "Should not have added an invite for the target player", 12345, Invite.InviterID )
	end )

	UnitTest:Test( "HandleFriendGroupJoinRequest - Client that requires an invite is rejected if the caller's group is full", function( Assert )
		MockPlugin.FriendGroupConfigBySteamID[ 789 ] = {
			LeaderType = VoteShuffle.FriendGroupLeaderType.ALLOW_ALL_TO_JOIN,
			JoinType = VoteShuffle.FriendGroupJoinType.REQUIRE_INVITE
		}
		MockPlugin.Config = {
			TeamPreferences = {
				MaxFriendGroupSize = 3
			}
		}
		VoteShuffle.HandleFriendGroupJoinRequest( MockPlugin, MockClient( 12345 ), MockClient( 789 ) )

		Assert:Equals( 1, #MockPlugin.FriendGroups )
		Assert:ArrayContainsExactly(
			{ MockClient( 12345 ), MockClient( 54321 ), MockClient( 67890 ) },
			MockPlugin.FriendGroups[ 1 ].Clients
		)
		Assert.Nil( "Should not have added the target to a group", MockPlugin.FriendGroupsBySteamID[ 789 ] )

		local Invite = MockPlugin.FriendGroupInvitesBySteamID[ 789 ]
		Assert.Nil( "Should not have added an invite for the target player", Invite )
	end )

	UnitTest:Test( "HandleFriendGroupJoinRequest - Client that requires an invite is rejected if the caller has recently invited the target", function( Assert )
		MockPlugin.FriendGroupConfigBySteamID[ 789 ] = {
			LeaderType = VoteShuffle.FriendGroupLeaderType.ALLOW_ALL_TO_JOIN,
			JoinType = VoteShuffle.FriendGroupJoinType.REQUIRE_INVITE
		}
		MockPlugin.FriendGroupInviteDelaysBySteamID = {
			[ 789 ] = {
				[ 123 ] = math.huge
			}
		}
		VoteShuffle.HandleFriendGroupJoinRequest( MockPlugin, MockClient( 123 ), MockClient( 789 ) )

		Assert:Equals( 1, #MockPlugin.FriendGroups )
		Assert:ArrayContainsExactly(
			{ MockClient( 12345 ), MockClient( 54321 ), MockClient( 67890 ) },
			MockPlugin.FriendGroups[ 1 ].Clients
		)
		Assert.Nil( "Should not have added the target to a group", MockPlugin.FriendGroupsBySteamID[ 789 ] )

		local Invite = MockPlugin.FriendGroupInvitesBySteamID[ 789 ]
		Assert.Nil( "Should not have added an invite for the target player", Invite )
	end )

	UnitTest:Test( "HandleFriendGroupJoinRequest - No groups for either client creates new group", function( Assert )
		VoteShuffle.HandleFriendGroupJoinRequest( MockPlugin, MockClient( 123 ), MockClient( 456 ) )

		Assert:Equals( 2, #MockPlugin.FriendGroups )
		Assert:ArrayContainsExactly( { MockClient( 123 ), MockClient( 456 ) }, MockPlugin.FriendGroups[ 2 ].Clients )
		Assert:Equals( MockPlugin.FriendGroups[ 2 ], MockPlugin.FriendGroupsBySteamID[ 123 ] )
		Assert:Equals( MockPlugin.FriendGroups[ 2 ], MockPlugin.FriendGroupsBySteamID[ 456 ] )
	end )

	UnitTest:Test( "HandleFriendGroupJoinRequest - Both in same group does nothing", function( Assert )
		VoteShuffle.HandleFriendGroupJoinRequest( MockPlugin, MockClient( 12345 ), MockClient( 54321 ) )

		Assert:Equals( 1, #MockPlugin.FriendGroups )
		Assert:ArrayContainsExactly(
			{ MockClient( 12345 ), MockClient( 54321 ), MockClient( 67890 ) },
			MockPlugin.FriendGroups[ 1 ].Clients
		)
		Assert:Equals( MockPlugin.FriendGroups[ 1 ], MockPlugin.FriendGroupsBySteamID[ 12345 ] )
		Assert:Equals( MockPlugin.FriendGroups[ 1 ], MockPlugin.FriendGroupsBySteamID[ 54321 ] )
	end )

	UnitTest:Test( "HandleFriendGroupJoinRequest - Both in different groups does nothing", function( Assert )
		VoteShuffle.HandleFriendGroupJoinRequest( MockPlugin, MockClient( 123 ), MockClient( 456 ) )
		VoteShuffle.HandleFriendGroupJoinRequest( MockPlugin, MockClient( 12345 ), MockClient( 456 ) )

		Assert:Equals( 2, #MockPlugin.FriendGroups )
		Assert:ArrayContainsExactly(
			{ MockClient( 12345 ), MockClient( 54321 ), MockClient( 67890 ) },
			MockPlugin.FriendGroups[ 1 ].Clients
		)
		Assert:ArrayContainsExactly( { MockClient( 123 ), MockClient( 456 ) }, MockPlugin.FriendGroups[ 2 ].Clients )
		Assert:Equals( MockPlugin.FriendGroups[ 1 ], MockPlugin.FriendGroupsBySteamID[ 12345 ] )
		Assert:Equals( MockPlugin.FriendGroups[ 1 ], MockPlugin.FriendGroupsBySteamID[ 54321 ] )
		Assert:Equals( MockPlugin.FriendGroups[ 2 ], MockPlugin.FriendGroupsBySteamID[ 123 ] )
		Assert:Equals( MockPlugin.FriendGroups[ 2 ], MockPlugin.FriendGroupsBySteamID[ 456 ] )
	end )

	UnitTest:Test( "HandleFriendGroupJoinRequest - No target group adds the target to the caller's group", function( Assert )
		VoteShuffle.HandleFriendGroupJoinRequest( MockPlugin, MockClient( 12345 ), MockClient( 456 ) )

		Assert:Equals( 1, #MockPlugin.FriendGroups )
		Assert:ArrayContainsExactly(
			{ MockClient( 12345 ), MockClient( 54321 ), MockClient( 67890 ), MockClient( 456 ) },
			MockPlugin.FriendGroups[ 1 ].Clients
		)
		Assert:Equals( MockPlugin.FriendGroups[ 1 ], MockPlugin.FriendGroupsBySteamID[ 456 ] )
	end )

	UnitTest:Test( "HandleFriendGroupJoinRequest - Adding to caller group fails if only the group's leader can invite", function( Assert )
		MockPlugin.FriendGroupConfigBySteamID[ 12345 ] = {
			LeaderType = VoteShuffle.FriendGroupLeaderType.LEADER_ADD_ONLY,
			JoinType = VoteShuffle.FriendGroupJoinType.ALLOW_ALL
		}
		VoteShuffle.HandleFriendGroupJoinRequest( MockPlugin, MockClient( 54321 ), MockClient( 456 ) )

		Assert:Equals( 1, #MockPlugin.FriendGroups )
		Assert:ArrayContainsExactly(
			{ MockClient( 12345 ), MockClient( 54321 ), MockClient( 67890 ) },
			MockPlugin.FriendGroups[ 1 ].Clients
		)
		Assert.Nil( "Target should not have been added to the group", MockPlugin.FriendGroupsBySteamID[ 456 ] )
	end )

	UnitTest:Test( "HandleFriendGroupJoinRequest - Adding to caller group fails if full", function( Assert )
		MockPlugin.Config.TeamPreferences.MaxFriendGroupSize = 3

		VoteShuffle.HandleFriendGroupJoinRequest( MockPlugin, MockClient( 12345 ), MockClient( 456 ) )

		Assert:Equals( 1, #MockPlugin.FriendGroups )
		Assert:ArrayContainsExactly(
			{ MockClient( 12345 ), MockClient( 54321 ), MockClient( 67890 ) },
			MockPlugin.FriendGroups[ 1 ].Clients
		)
		Assert.Nil( "Target should not have been added to the group", MockPlugin.FriendGroupsBySteamID[ 456 ] )
	end )

	UnitTest:Test( "HandleFriendGroupJoinRequest - No caller group adds the caller to the target's group", function( Assert )
		-- Simulate invites sent from the player that's joining the group.
		MockPlugin.FriendGroupInvitesBySteamID[ 789 ] = {
			InviterID = 456,
			ExpiryTime = math.huge
		}

		VoteShuffle.HandleFriendGroupJoinRequest( MockPlugin, MockClient( 456 ), MockClient( 12345 ) )

		Assert:Equals( 1, #MockPlugin.FriendGroups )
		Assert:ArrayContainsExactly(
			{ MockClient( 12345 ), MockClient( 54321 ), MockClient( 67890 ), MockClient( 456 ) },
			MockPlugin.FriendGroups[ 1 ].Clients
		)
		Assert:Equals( MockPlugin.FriendGroups[ 1 ], MockPlugin.FriendGroupsBySteamID[ 456 ] )

		Assert.NotNil( "Should not cancel any pending invites as the group is open to all",
			MockPlugin.FriendGroupInvitesBySteamID[ 789 ] )
	end )

	UnitTest:Test( "HandleFriendGroupJoinRequest - Adding to target group succeeds if only the group's leader can invite and the player is invited", function( Assert )
		MockPlugin.FriendGroupConfigBySteamID[ 12345 ] = {
			LeaderType = VoteShuffle.FriendGroupLeaderType.LEADER_ADD_ONLY,
			JoinType = VoteShuffle.FriendGroupJoinType.ALLOW_ALL
		}
		MockPlugin.FriendGroupInvitesBySteamID[ 456 ] = {
			InviterID = 12345,
			ExpiryTime = math.huge
		}

		-- Simulate invites sent from the player that's joining the group.
		MockPlugin.FriendGroupInvitesBySteamID[ 789 ] = {
			InviterID = 456,
			ExpiryTime = math.huge
		}
		MockPlugin.FriendGroupInvitesBySteamID[ 987 ] = {
			InviterID = 456,
			ExpiryTime = math.huge
		}

		VoteShuffle.HandleFriendGroupJoinRequest( MockPlugin, MockClient( 456 ), MockClient( 12345 ) )

		Assert:Equals( 1, #MockPlugin.FriendGroups )
		Assert:ArrayContainsExactly(
			{ MockClient( 12345 ), MockClient( 54321 ), MockClient( 67890 ), MockClient( 456 ) },
			MockPlugin.FriendGroups[ 1 ].Clients
		)
		Assert:Equals( MockPlugin.FriendGroups[ 1 ], MockPlugin.FriendGroupsBySteamID[ 456 ] )

		Assert.Nil( "Should remove the consumed invite for the caller",
			MockPlugin.FriendGroupInvitesBySteamID[ 456 ] )
		Assert.Nil( "Should cancel any pending invites as the group is leader invite only",
			MockPlugin.FriendGroupInvitesBySteamID[ 789 ] )
		Assert.Nil( "Should cancel any pending invites as the group is leader invite only",
			MockPlugin.FriendGroupInvitesBySteamID[ 987 ] )
	end )

	UnitTest:Test( "HandleFriendGroupJoinRequest - Adding to target group fails if only the group's leader can invite", function( Assert )
		MockPlugin.FriendGroupConfigBySteamID[ 12345 ] = {
			LeaderType = VoteShuffle.FriendGroupLeaderType.LEADER_ADD_ONLY,
			JoinType = VoteShuffle.FriendGroupJoinType.ALLOW_ALL
		}
		VoteShuffle.HandleFriendGroupJoinRequest( MockPlugin, MockClient( 456 ), MockClient( 12345 ) )

		Assert:Equals( 1, #MockPlugin.FriendGroups )
		Assert:ArrayContainsExactly(
			{ MockClient( 12345 ), MockClient( 54321 ), MockClient( 67890 ) },
			MockPlugin.FriendGroups[ 1 ].Clients
		)
		Assert.Nil( "Target should not have been added to the group", MockPlugin.FriendGroupsBySteamID[ 456 ] )
	end )

	UnitTest:Test( "HandleFriendGroupJoinRequest - Adding to target group fails if full", function( Assert )
		MockPlugin.Config.TeamPreferences.MaxFriendGroupSize = 3

		VoteShuffle.HandleFriendGroupJoinRequest( MockPlugin, MockClient( 456 ), MockClient( 12345 ) )

		Assert:Equals( 1, #MockPlugin.FriendGroups )
		Assert:ArrayContainsExactly(
			{ MockClient( 12345 ), MockClient( 54321 ), MockClient( 67890 ) },
			MockPlugin.FriendGroups[ 1 ].Clients
		)
		Assert.Nil( "Caller should not have been added to the group", MockPlugin.FriendGroupsBySteamID[ 456 ] )
	end )

	UnitTest:Test( "RemoveClientFromFriendGroup - Leaves group in place when enough members remain", function( Assert )
		MockPlugin.FriendGroupInvitesBySteamID[ 456 ] = {
			InviterID = 12345,
			ExpiryTime = math.huge
		}

		VoteShuffle.RemoveClientFromFriendGroup( MockPlugin, MockPlugin.FriendGroups[ 1 ], MockClient( 12345 ) )

		Assert:Equals( 1, #MockPlugin.FriendGroups )
		Assert:ArrayContainsExactly(
			{ MockClient( 54321 ), MockClient( 67890 ) },
			MockPlugin.FriendGroups[ 1 ].Clients
		)
		Assert.Equals( "Should have updated the group leader", MockClient( 54321 ), MockPlugin.FriendGroups[ 1 ].Leader )
		Assert.Nil( "Removed client should no longer be mapped to the group", MockPlugin.FriendGroupsBySteamID[ 12345 ] )
		Assert.Nil( "Should have cancelled invites from the client being removed",
			MockPlugin.FriendGroupInvitesBySteamID[ 456 ] )
	end )

	UnitTest:Test( "RemoveClientFromFriendGroup - Does not change leader when leader is still present", function( Assert )
		VoteShuffle.RemoveClientFromFriendGroup( MockPlugin, MockPlugin.FriendGroups[ 1 ], MockClient( 54321 ) )

		Assert:Equals( 1, #MockPlugin.FriendGroups )
		Assert:ArrayContainsExactly(
			{ MockClient( 12345 ), MockClient( 67890 ) },
			MockPlugin.FriendGroups[ 1 ].Clients
		)
		Assert.Equals( "Should not have changed the group leader", MockClient( 12345 ), MockPlugin.FriendGroups[ 1 ].Leader )
		Assert.Nil( "Removed client should no longer be mapped to the group", MockPlugin.FriendGroupsBySteamID[ 54321 ] )
	end )

	UnitTest:Test( "RemoveClientFromFriendGroup - Removes group when only 1 member remains", function( Assert )
		VoteShuffle.RemoveClientFromFriendGroup( MockPlugin, MockPlugin.FriendGroups[ 1 ], MockClient( 12345 ) )
		VoteShuffle.RemoveClientFromFriendGroup( MockPlugin, MockPlugin.FriendGroups[ 1 ], MockClient( 54321 ) )

		Assert:Equals( 0, #MockPlugin.FriendGroups )
		Assert.DeepEquals( "All clients should be removed from the group", {}, MockPlugin.FriendGroupsBySteamID )
	end )

	UnitTest:ResetState()
end

UnitTest:Test( "BuildEnforcementPolicy - Returns NoOpEnforcement if no policies are specified", function( Assert )
	local Enforcement = VoteShuffle:BuildEnforcementPolicy( {
		EnforcementPolicy = {}
	} )

	Assert.Nil( "Should have no policies to enforce", Enforcement.Policies )
end )

UnitTest:Test( "BuildEnforcementPolicy - Returns NoOpEnforcement if EnforcementDurationType == 'NONE'", function( Assert )
	local Enforcement = VoteShuffle:BuildEnforcementPolicy( {
		EnforcementPolicy = {
			{
				Type = VoteShuffle.EnforcementPolicyType.BLOCK_TEAMS,
				MinPlayers = 0,
				MaxPlayers = 0
			}
		},
		EnforcementDurationType = VoteShuffle.EnforcementDurationType.NONE
	} )

	Assert.Nil( "Should have no policies to enforce", Enforcement.Policies )
end )

UnitTest:Test( "BuildEnforcementPolicy - Returns NoOpEnforcement if duration is too small", function( Assert )
	local Enforcement = VoteShuffle:BuildEnforcementPolicy( {
		EnforcementPolicy = {
			{
				Type = VoteShuffle.EnforcementPolicyType.BLOCK_TEAMS,
				MinPlayers = 0,
				MaxPlayers = 0
			}
		},
		DurationInMinutes = 0,
		EnforcementDurationType = VoteShuffle.EnforcementDurationType.TIME
	} )

	Assert.Nil( "Should have no policies to enforce", Enforcement.Policies )
end )

UnitTest:Test( "BuildEnforcementPolicy - Returns DurationBasedEnforcement if duration is large enough", function( Assert )
	local Enforcement = VoteShuffle:BuildEnforcementPolicy( {
		EnforcementPolicy = {
			{
				Type = VoteShuffle.EnforcementPolicyType.BLOCK_TEAMS,
				MinPlayers = 10,
				MaxPlayers = 15
			}
		},
		DurationInMinutes = 10,
		EnforcementDurationType = VoteShuffle.EnforcementDurationType.TIME
	} )

	Assert.DeepEquals( "Should have policies to enforce", {
		[ VoteShuffle.EnforcementPolicyType.BLOCK_TEAMS ] = {
			Type = VoteShuffle.EnforcementPolicyType.BLOCK_TEAMS,
			MinPlayers = 10,
			MaxPlayers = 15
		}
	}, Enforcement.Policies )

	Assert.False(
		"Should not enforce policy that is not specified",
		Enforcement:IsPolicyEnforced( VoteShuffle.EnforcementPolicyType.ASSIGN_PLAYERS, 10 )
	)
	Assert.False(
		"Should not enforce policy when player count is too low",
		Enforcement:IsPolicyEnforced( VoteShuffle.EnforcementPolicyType.BLOCK_TEAMS, 9 )
	)
	Assert.False(
		"Should not enforce policy when player count is too high",
		Enforcement:IsPolicyEnforced( VoteShuffle.EnforcementPolicyType.BLOCK_TEAMS, 16 )
	)
	for i = 10, 15 do
		Assert.True(
			"Should enforce policy when player count ("..i..") is within bounds",
			Enforcement:IsPolicyEnforced( VoteShuffle.EnforcementPolicyType.BLOCK_TEAMS, i )
		)
	end
end )

UnitTest:Test( "BuildEnforcementPolicy - Returns PeriodBasedEnforcement if configured to do so", function( Assert )
	local Enforcement = VoteShuffle:BuildEnforcementPolicy( {
		EnforcementPolicy = {
			{
				Type = VoteShuffle.EnforcementPolicyType.BLOCK_TEAMS,
				MinPlayers = 0,
				MaxPlayers = 0
			}
		},
		DurationInMinutes = 10,
		EnforcementDurationType = VoteShuffle.EnforcementDurationType.PERIOD
	} )

	Assert.DeepEquals( "Should have policies to enforce", {
		[ VoteShuffle.EnforcementPolicyType.BLOCK_TEAMS ] = {
			Type = VoteShuffle.EnforcementPolicyType.BLOCK_TEAMS,
			MinPlayers = 0,
			MaxPlayers = 0
		}
	}, Enforcement.Policies )
	Assert.NotNil( "Should return period based enforcement", Enforcement.InitialStage )
end )

----- Integration tests for team optimisation -----

-- Turn off happiness optimisation for integration tests.
VoteShuffle.OptimiseHappiness = function() end

UnitTest:Test( "OptimiseTeams", function( Assert )
	local Skills = {
		2000, 2000, 1000,
		1000, 1000, 1000
	}

	local function RankFunc( Player )
		return Skills[ Player ]
	end

	local TeamMembers = {
		{
			1, 2, 3
		},
		{
			4, 5, 6
		},
		TeamPreferences = {}
	}

	local TeamSkills = {
		{
			Average = 5000 / 3,
			Total = 5000,
			Count = 3
		},
		{
			Average = 1000,
			Total = 3000,
			Count = 3
		}
	}

	VoteShuffle:OptimiseTeams( TeamMembers, RankFunc, TeamSkills )

	-- Final team layout should be:
	-- 2000, 1000, 1000
	-- 2000, 1000, 1000
	Assert:Equals( 4000, TeamSkills[ 1 ].Total )
	Assert:Equals( 4000, TeamSkills[ 2 ].Total )
end, nil, 5 )

UnitTest:Test( "OptimiseLargeTeams", function( Assert )
	local Skills = {
		2000, 2000, 2000, 1800, 1700, 1500, 1200, 1000,
		1000, 1000, 1000, 700, 600, 500, 0, 0
	}

	local function RankFunc( Player )
		return Skills[ Player ]
	end

	local TeamMembers = {
		{
			1, 2, 3, 4, 5, 6, 7, 8
		},
		{
			9, 10, 11, 12, 13, 14, 15, 16
		},
		TeamPreferences = {}
	}

	local TeamSkills = {}
	local Team = 1
	local PerTeam = #Skills * 0.5
	for i = 1, #Skills, PerTeam do
		local Data = {}
		local Sum = 0

		for j = i, i + PerTeam - 1 do
			Sum = Sum + Skills[ j ]
		end

		Data.Total = Sum
		Data.Average = Sum / PerTeam
		Data.Count = PerTeam

		TeamSkills[ Team ] = Data
		Team = Team + 1
	end

	VoteShuffle:OptimiseTeams( TeamMembers, RankFunc, TeamSkills )

	local FinalTeams = {
		{ 2000, 1800, 1700, 1200, 1000, 700, 600, 0 },
		{ 2000, 2000, 1500, 1000, 1000, 1000, 500, 0 }
	}

	for i = 1, 2 do
		local TeamTable = TeamMembers[ i ]
		TableSort( TeamTable, function( A, B )
			return Skills[ A ] > Skills[ B ]
		end )

		local AsSkillArray = {}
		for j = 1, #TeamTable do
			AsSkillArray[ j ] = Skills[ TeamTable[ j ] ]
		end

		Assert:ArrayEquals( FinalTeams[ i ], AsSkillArray )
	end
end, nil, 5 )

UnitTest:Test( "OptimiseTeams with uneven teams", function( Assert )
	local Skills = {
		2000, 2000, 1000,
		1000, 1000
	}

	local function RankFunc( Player )
		return Skills[ Player ]
	end

	local TeamMembers = {
		{
			1, 2, 3
		},
		{
			4, 5
		},
		TeamPreferences = {}
	}

	local TeamSkills = {
		{
			Average = 5000 / 3,
			Total = 5000,
			Count = 3
		},
		{
			Average = 1000,
			Total = 2000,
			Count = 2
		}
	}

	VoteShuffle:OptimiseTeams( TeamMembers, RankFunc, TeamSkills )

	-- Final team layout should be:
	-- 2000, 1000
	-- 2000, 1000, 1000
	Assert:Equals( 3000, TeamSkills[ 1 ].Total )
	Assert:Equals( 2, TeamSkills[ 1 ].Count )
	Assert:Equals( 4000, TeamSkills[ 2 ].Total )
	Assert:Equals( 3, TeamSkills[ 2 ].Count )
end, nil, 5 )

UnitTest:Test( "OptimiseTeams with preference", function( Assert )
	local Skills = {
		2000, 2000, 1000,
		1000, 1000, 1000
	}

	local function RankFunc( Player )
		return Skills[ Player ]
	end

	local TeamMembers = {
		{
			1, 2, 3
		},
		{
			4, 5, 6
		},
		TeamPreferences = {
			[ 4 ] = true,
			[ 5 ] = true
		}
	}

	local TeamSkills = {
		{
			Average = 5000 / 3,
			Total = 5000,
			Count = 3
		},
		{
			Average = 1000,
			Total = 3000,
			Count = 3
		}
	}

	VoteShuffle:OptimiseTeams( TeamMembers, RankFunc, TeamSkills )

	-- It should always swap 2 and 6, as 4 and 5 have chosen team 2 specifically.
	Assert:ArrayContainsExactly( { 1, 6, 3 }, TeamMembers[ 1 ] )
	Assert:ArrayContainsExactly( { 4, 5, 2 }, TeamMembers[ 2 ] )
end, nil, 5 )

VoteShuffle.Config.IgnoreCommanders = true

UnitTest:Test( "OptimiseTeams with commanders", function( Assert )
	local Index = 0
	local Players = {}
	local function Player( Skill, Commander )
		Index = Index + 1
		Players[ Index ] = {
			Index = Index,
			Skill = Skill,
			isa = function() return Commander end,
			Commander = Commander
		}
		return Players[ Index ]
	end

	local Marines = {
		Player( 2000, true ), Player( 2000 ), Player( 1000 )
	}
	local Aliens = {
		Player( 1000, true ), Player( 1000 ), Player( 1000 )
	}

	local function RankFunc( Player )
		return Player.Skill
	end

	local TeamMembers = {
		Marines,
		Aliens,
		TeamPreferences = {
			[ Marines[ 1 ] ] = true,
			[ Aliens[ 1 ] ] = true
		}
	}

	local TeamSkills = {
		{
			Average = 5000 / 3,
			Total = 5000,
			Count = 3
		},
		{
			Average = 1000,
			Total = 3000,
			Count = 3
		}
	}

	VoteShuffle:OptimiseTeams( TeamMembers, RankFunc, TeamSkills )

	-- It should never swap the commanders.
	Assert:ArrayContainsExactly( { Players[ 1 ], Players[ 6 ], Players[ 3 ] }, TeamMembers[ 1 ] )
	Assert:ArrayContainsExactly( { Players[ 4 ], Players[ 5 ], Players[ 2 ] }, TeamMembers[ 2 ] )
end, nil, 5 )

UnitTest:Test( "OptimiseTeams with friend groups", function( Assert )
	local Index = 0
	local Players = {}
	local function Player( Skill, Commander )
		Index = Index + 1
		Players[ Index ] = {
			Index = Index,
			Skill = Skill,
			isa = function() return Commander end,
			Commander = Commander
		}
		return Players[ Index ]
	end

	local Marines = {
		Player( 2000, true ), Player( 1000 ), Player( 1000 )
	}
	local Aliens = {
		Player( 2000, true ), Player( 1000 ), Player( 1000 )
	}

	local function RankFunc( Player )
		return Player.Skill
	end

	local TeamMembers = {
		Marines,
		Aliens,
		TeamPreferences = {},
		PlayerGroups = {
			{
				Players = {
					Marines[ 2 ], Aliens[ 3 ]
				}
			}
		}
	}

	local TeamSkills = {
		{
			Average = 4000 / 3,
			Total = 4000,
			Count = 3
		},
		{
			Average = 4000 / 3,
			Total = 4000,
			Count = 3
		}
	}

	VoteShuffle:OptimiseTeams( TeamMembers, RankFunc, TeamSkills )

	-- It should swap the players that are grouped as it will not harm the balance.
	Assert:ArrayContainsExactly( { Players[ 1 ], Players[ 2 ], Players[ 6 ] }, TeamMembers[ 1 ] )
	Assert:ArrayContainsExactly( { Players[ 4 ], Players[ 5 ], Players[ 3 ] }, TeamMembers[ 2 ] )
end )

VoteShuffle.OptimiseHappiness = BalanceModule.OptimiseHappiness
