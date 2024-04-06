# SimpleConfig

This plugin allows for simple configuration on what weapon slots can be dropped and picked up per team.

The configuration is generated in ``tf/addons/sourcemod/configs/dropweapon.cfg`` and is structured like this:

```
"DropWeapon"
{
    "action_drop"
    {
        "slot" "permission"
        // or
        "slot"
        {
            "team" "permission"
        }
    }
    "action_pickup"
    {
        // same as action_drop
    }
}
```

### Possible values for slot:
* ``primary``  - the big guns.
* ``secondary``  - smaller guns and pistols (spy revolvers are here too).
* ``melee``  - stabby and bashy things.
* ``pda``  - construction pad for engi, disguise kit for spy.
* ``pda2``  - destruction pad for engi, watch for spy.
* ``action``  - grappling hook.
* ``building``  - sapper for spy (technically carried buildings for engi, but those can't be dropped anyways).
* itemdef  - any valid item definition index (see the list of [TF2 Item Definition Indices](https://wiki.alliedmods.net/Team_Fortress_2_Item_Definition_Indexes))

Small hint on multiclass weapons like the shotgun:    
TF2DropWeapon does internal class translation of the item definition,
which matches the item index to the actual player class, which is for some reason needed for stock weapons.
This might mess with indices as you put them in the config.
    
### Possible values for permission
* empty or ``everyone``  - no restriction, everyone can do.
* ``nobody``  - nobody can do.
* flagstring like ``ao``  - requires the player to have all permission flags.
* command name like ``sm_ban``  - requires the player to have the command override or access to the command.
  you can prefix the command with a slash to make it obvious, that you mean a command, but it should work without.

### Possible values for team
* ``red``  - the ones in the red shirts
* ``blue``  - the ones with the other shirts
* ``spec``  - this is where player bosses usually live
* ``boss``  - merasmus and co (I don't know any way a player could join this team without crashing, but you get it anyways)

The default value, for every team/slot that is not specified is ``everyone``, so things should run without interruption
