-- { [mob]="elem\004src\004value\003..." } ; src d=damage%% (>100 weak/<100 resist/0 immune/<0 absorb),
-- k=element rank, t=status (value = statusid*10 + state[1 weak/2 resist/3 immune]; icon = buff <id>.png).
return {
["alexander"]="Fire\004k\0045\003Ice\004k\0045\003Wind\004k\0045\003Earth\004k\0045\003Lightning\004k\0045\003Water\004k\0045\003Light\004k\00411\003Dark\004k\0045\003Paralyze\004t\004425\003Bind\004t\0041125\003Silence\004t\004625\003Slow\004t\0041325\003Poison\004t\004325\003Sleep\004t\004231\003Blind\004t\004525",
["mimic"]="Slashing\004d\00450\003Piercing\004d\00450\003Ranged\004d\00450\003H2H\004d\00450\003Impact\004d\00450",
["odin prime"]="Light\004k\004-3\003Dark\004k\00411\003Sleep\004t\004231\003Blind\004t\004531",
}
