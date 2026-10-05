# Reconstruit base.json à partir des settings courants ($cur) sans y remonter les
# surcharges de local.json ($loc) : pour chaque chemin feuille de $loc (un tableau
# compte comme une feuille), on reprend la valeur de $base si elle existe, sinon on
# supprime le chemin, puis on retire les objets devenus vides absents de $base.

def leafpaths:
  if type == "object" then
    to_entries[] | .key as $k | (.value | leafpaths | [$k] + .)
  else
    []
  end;

def haspath($p):
  if ($p | length) == 0 then true
  else (try (getpath($p[:-1]) | type == "object" and has($p[-1])) catch false)
  end;

def prune($b; $p):
  if ($p | length) == 0 then .
  elif ((try getpath($p) catch null) == {}) and (($b | haspath($p)) | not) then
    delpaths([$p]) | prune($b; $p[:-1])
  else .
  end;

$cur[0] as $c
| $base[0] as $b
| $loc[0] as $l
| reduce ($l | leafpaths) as $p ($c;
    . as $acc
    | if ($b | haspath($p)) then
        (try setpath($p; $b | getpath($p)) catch $acc)
      else
        (try delpaths([$p]) catch $acc) | prune($b; $p[:-1])
      end)
