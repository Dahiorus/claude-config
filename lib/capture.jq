# Reconstruit base.json à partir des settings courants ($cur) sans y remonter les
# surcharges de local.json ($loc) : pour chaque chemin feuille de $loc (un tableau
# compte comme une feuille, un objet vide aussi), on reprend la valeur de $base si elle existe, sinon on
# supprime le chemin, puis on retire les objets devenus vides absents de $base.

def leafpaths:
  if type == "object" and length > 0 then
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

# Si $loc a remplacé un scalaire de $base par un objet, remet ce scalaire en place.
def restore_scalar($b; $p):
  ([range(($p | length) - 1; 0; -1) as $i | $p[:$i] | select(. as $q | $b | haspath($q))] | first) as $q
  | if $q != null and (($b | getpath($q)) | type) != "object" then setpath($q; $b | getpath($q))
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
        | restore_scalar($b; $p)
      end)
