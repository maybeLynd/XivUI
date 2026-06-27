-- { [mob]="elem\004src\004value\003..." } ; src d=damage%% (>100 weak/<100 resist/0 immune/<0 absorb),
-- k=element rank, t=status (value = statusid*10 + state[1 weak/2 resist/3 immune]; icon = buff <id>.png).
return {
["fire elemental"]="Slashing\004d\00425\003Piercing\004d\00425\003Ranged\004d\00425\003H2H\004d\00425\003Impact\004d\00425\003Fire\004k\00411\003Ice\004k\00411\003Water\004k\004-3\003Paralyze\004t\004431\003Bind\004t\0041131\003Poison\004t\004317\003Silence\004t\004631",
["ifrit prime"]="Fire\004k\00411\003Ice\004k\00411\003Wind\004k\00411\003Earth\004k\00411\003Lightning\004k\00411\003Water\004k\004-3\003Light\004k\00411\003Dark\004k\00411\003Paralyze\004t\004431\003Bind\004t\0041131\003Silence\004t\004631\003Slow\004t\0041331\003Poison\004t\004317\003Sleep\004t\004231\003Blind\004t\004531",
}
