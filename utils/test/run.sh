#!/bin/bash -e
world=$(mktemp -d)
trap 'rm -rf "$world" || :' EXIT

[ -f game.conf ] || { echo "Must be run in game root folder." >&2; exit 1; }
[ -n "$DOCKER_IMAGE" ] || { echo "Specify a docker image." >&2; exit 1; }

chmod -R 777 "$world" # container uses unprivileged user inside

vol=(
	-v "$PWD/utils/test/minetest.conf":/etc/minetest/minetest.conf
	--tmpfs /var/lib/minetest/.minetest
	-v "$PWD":/var/lib/minetest/.minetest/games/minetest_game
	-v "$world":/var/lib/minetest/.minetest/world
)
docker run --rm -i "${vol[@]}" "$DOCKER_IMAGE" --config /etc/minetest/minetest.conf --gameid minetest

test -f "$world/map.sqlite" || exit 1
exit 0
