using Godot;
using System;
using System.Collections.Generic;

namespace Framework.Content;

/// <summary>
/// Central registry for all loaded content
/// </summary>
public partial class ContentRegistry : RefCounted
{
    public signal void PlayerRegistered(string playerId);
    public signal void TeamRegistered(string teamId);
    public signal void SelectionRegistered(string selectionId);
    public signal void PlayerUpdated(string playerId);
    public signal void TeamUpdated(string teamId);
    public signal void AllContentCleared();

    private Dictionary<string, Dictionary> _players = new();
    private Dictionary<string, Dictionary> _teams = new();
    private Dictionary<string, Dictionary> _selections = new();
    private Dictionary<string, Array> _selectionsByCategory = new();
    private Dictionary _gameRules = new();
    private Dictionary _manifest = new();

    public override string ToString()
    {
        return $"ContentRegistry[players={_players.Count}, teams={_teams.Count}, selections={_selections.Count}]";
    }

    public bool RegisterPlayer(Dictionary player)
    {
        string playerId = player.TryGetValue("id", out var id) ? id.ToString() : "";
        if (string.IsNullOrEmpty(playerId))
        {
            PushError("Cannot register player with empty ID");
            return false;
        }

        if (_players.ContainsKey(playerId))
        {
            PushWarning($"Player already registered: {playerId}");
            return false;
        }

        _players[playerId] = player;
        EmitSignal(nameof(PlayerRegistered), playerId);
        return true;
    }

    public bool RegisterTeam(Dictionary team)
    {
        string teamId = team.TryGetValue("id", out var id) ? id.ToString() : "";
        if (string.IsNullOrEmpty(teamId))
        {
            PushError("Cannot register team with empty ID");
            return false;
        }

        if (_teams.ContainsKey(teamId))
        {
            PushWarning($"Team already registered: {teamId}");
            return false;
        }

        _teams[teamId] = team;
        EmitSignal(nameof(TeamRegistered), teamId);
        return true;
    }

    public bool RegisterSelection(Dictionary selection)
    {
        string selectionId = selection.TryGetValue("id", out var id) ? id.ToString() : "";
        if (string.IsNullOrEmpty(selectionId))
        {
            PushError("Cannot register selection with empty ID");
            return false;
        }

        if (_selections.ContainsKey(selectionId))
        {
            PushWarning($"Selection already registered: {selectionId}");
            return false;
        }

        _selections[selectionId] = selection;

        string category = selection.TryGetValue("_category", out var cat) ? cat.ToString() : "uncategorized";
        if (!_selectionsByCategory.ContainsKey(category))
        {
            _selectionsByCategory[category] = new Array();
        }
        _selectionsByCategory[category].Add(selection);

        EmitSignal(nameof(SelectionRegistered), selectionId);
        return true;
    }

    public Dictionary GetPlayer(string playerId)
    {
        return _players.TryGetValue(playerId, out var player) ? player : new Dictionary();
    }

    public Dictionary GetTeam(string teamId)
    {
        return _teams.TryGetValue(teamId, out var team) ? team : new Dictionary();
    }

    public Dictionary GetSelection(string selectionId)
    {
        return _selections.TryGetValue(selectionId, out var selection) ? selection : new Dictionary();
    }

    public Array GetAllPlayers()
    {
        return new Array(_players.Values);
    }

    public Array GetAllTeams()
    {
        return new Array(_teams.Values);
    }

    public Array GetAllSelections()
    {
        return new Array(_selections.Values);
    }

    public Array GetSelectionsByCategory(string category)
    {
        return _selectionsByCategory.TryGetValue(category, out var selections) ? selections : new Array();
    }

    public string[] GetCategories()
    {
        var keys = new string[_selectionsByCategory.Count];
        _selectionsByCategory.Keys.CopyTo(keys, 0);
        return keys;
    }

    public Array GetPlayersByTeam(string teamId)
    {
        var result = new Array();
        foreach (var player in _players.Values)
        {
            if (player.TryGetValue("team_id", out var pid) && pid.ToString() == teamId)
            {
                result.Add(player);
            }
        }
        return result;
    }

    public Dictionary GetTeamCaptain(string teamId)
    {
        var players = GetPlayersByTeam(teamId);
        foreach (Dictionary player in players)
        {
            if (player.TryGetValue("captain", out var captain) && (bool)captain)
            {
                return player;
            }
        }
        return new Dictionary();
    }

    public Dictionary GetGameRules()
    {
        return _gameRules;
    }

    public Dictionary GetManifest()
    {
        return _manifest;
    }

    public bool HasPlayer(string playerId) => _players.ContainsKey(playerId);
    public bool HasTeam(string teamId) => _teams.ContainsKey(teamId);
    public bool HasSelection(string selectionId) => _selections.ContainsKey(selectionId);

    public bool UpdatePlayer(string playerId, Dictionary updates)
    {
        if (!_players.ContainsKey(playerId))
        {
            PushError($"Cannot update non-existent player: {playerId}");
            return false;
        }

        var player = _players[playerId];
        foreach (var key in updates.Keys)
        {
            player[key] = updates[key];
        }
        _players[playerId] = player;
        EmitSignal(nameof(PlayerUpdated), playerId);
        return true;
    }

    public bool UpdateTeam(string teamId, Dictionary updates)
    {
        if (!_teams.ContainsKey(teamId))
        {
            PushError($"Cannot update non-existent team: {teamId}");
            return false;
        }

        var team = _teams[teamId];
        foreach (var key in updates.Keys)
        {
            team[key] = updates[key];
        }
        _teams[teamId] = team;
        EmitSignal(nameof(TeamUpdated), teamId);
        return true;
    }

    public void LoadFromResults(Dictionary results)
    {
        if (results.TryGetValue("manifest", out var manifest) && manifest is Dictionary manifestDict)
        {
            _manifest = manifestDict;
        }

        if (results.TryGetValue("game_rules", out var rules) && rules is Dictionary rulesDict)
        {
            _gameRules = rulesDict;
        }

        if (results.TryGetValue("players", out var players) && players is Array playersArray)
        {
            foreach (var player in playersArray)
            {
                if (player is Dictionary playerDict)
                {
                    RegisterPlayer(playerDict);
                }
            }
        }

        if (results.TryGetValue("teams", out var teams) && teams is Array teamsArray)
        {
            foreach (var team in teamsArray)
            {
                if (team is Dictionary teamDict)
                {
                    RegisterTeam(teamDict);
                }
            }
        }

        if (results.TryGetValue("selections", out var selections) && selections is Array selectionsArray)
        {
            foreach (var selection in selectionsArray)
            {
                if (selection is Dictionary selectionDict)
                {
                    RegisterSelection(selectionDict);
                }
            }
        }
    }

    public void ClearAll()
    {
        _players.Clear();
        _teams.Clear();
        _selections.Clear();
        _selectionsByCategory.Clear();
        _gameRules.Clear();
        _manifest.Clear();
        EmitSignal(nameof(AllContentCleared));
    }

    public Array SerializePlayers()
    {
        return new Array(_players.Values);
    }

    public Array SerializeTeams()
    {
        return new Array(_teams.Values);
    }

    public Dictionary GetStats()
    {
        return new Dictionary
        {
            ["total_players"] = _players.Count,
            ["total_teams"] = _teams.Count,
            ["total_selections"] = _selections.Count,
            ["categories"] = new Array(_selectionsByCategory.Keys),
            ["players_by_team"] = CountPlayersByTeam()
        };
    }

    private Dictionary CountPlayersByTeam()
    {
        var counts = new Dictionary();
        foreach (var player in _players.Values)
        {
            if (player.TryGetValue("team_id", out var teamId))
            {
                string tid = teamId.ToString();
                counts[tid] = counts.TryGetValue(tid, out var count) ? (int)count + 1 : 1;
            }
        }
        return counts;
    }
}
