--[[
	Shuffling logic tests.
]]

local UnitTest = Shine.UnitTest

local VoteShuffle = UnitTest:LoadExtension( "voterandom" )
if not VoteShuffle or not VoteShuffle.Config then return end

VoteShuffle.Config.IgnoreCommanders = false
VoteShuffle.Config.UseStandardDeviation = true
VoteShuffle.Config.StandardDeviationTolerance = 40

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

----- Integration tests for team optimisation -----
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
	Assert:ArrayEquals( { 1, 6, 3 }, TeamMembers[ 1 ] )
	Assert:ArrayEquals( { 4, 5, 2 }, TeamMembers[ 2 ] )
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
	Assert:ArrayEquals( { Players[ 1 ], Players[ 6 ], Players[ 3 ] }, TeamMembers[ 1 ] )
	Assert:ArrayEquals( { Players[ 4 ], Players[ 5 ], Players[ 2 ] }, TeamMembers[ 2 ] )
end, nil, 5 )
