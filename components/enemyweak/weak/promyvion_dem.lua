
-- { [mob]="elem\004src\004value\003..." } ; src d=damage%% (>100 weak/<100 resist/0 immune/<0 absorb),
-- k=element rank, t=status (value = statusid*10 + state[1 weak/2 resist/3 immune]; icon = buff <id>.png).
return {
["apex idle drifter"]="Fire\004k\004-3\003Ice\004k\00411\003Wind\004k\00411\003Paralyze\004t\004431\003Bind\004t\0041131\003Silence\004t\004631",
["apex livid rager"]="Fire\004k\00411\003Ice\004k\00411\003Water\004k\004-3\003Paralyze\004t\004431\003Bind\004t\0041131\003Poison\004t\004317",
["apex woeful lamenter"]="Light\004k\004-3\003Dark\004k\00411\003Sleep\004t\004231\003Blind\004t\004531",
["gorger"]="Ice\004k\004-3\003Wind\004k\00411\003Earth\004k\00411\003Paralyze\004t\004417\003Bind\004t\0041117\003Silence\004t\004631\003Slow\004t\0041331",
["memory receptacle"]="Slashing\004d\004200\003Piercing\004d\004200\003Ranged\004d\004200\003H2H\004d\004200\003Impact\004d\004200",
["satiator"]="Ice\004k\004-3\003Wind\004k\00411\003Earth\004k\00411\003Paralyze\004t\004417\003Bind\004t\0041117\003Silence\004t\004631\003Slow\004t\0041331",
["seether"]="Fire\004k\00411\003Ice\004k\00411\003Water\004k\004-3\003Paralyze\004t\004431\003Bind\004t\0041131\003Poison\004t\004317",
["wanderer"]="Fire\004k\004-3\003Ice\004k\00411\003Wind\004k\00411\003Paralyze\004t\004431\003Bind\004t\0041131\003Silence\004t\004631",
["weeper"]="Light\004k\004-3\003Dark\004k\00411\003Sleep\004t\004231\003Blind\004t\004531",
}
