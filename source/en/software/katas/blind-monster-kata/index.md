<!-- BEGIN ARISE ------------------------------
Title:: "Blind Monster Kata"

Author:: "Jose Falanga"
Description:: "Kata to try the Mute Ping Pong constrain"
Language:: "en"
Thumbnail:: "kanagawa.jpg"
Published Date:: "2025-09-08"
Modified Date:: "2022-09-08"

content_header:: "false"
rss_hide:: "true"
---- END ARISE \\ DO NOT MODIFY THIS LINE ---->
# Blind Monster Kata
## Constrains
[Mute Ping Pong](https://kata-log.rocks/mute-ping-pong)

## Rules
Write the core system of game, with the following rules:
- There is a human in a room.
- The room is represented throug a grid of tiles of arbitrary size.
- The human starts in an arbitrary place in the room.
- The human can move anywhere in the room.
- The goal of the human is escaping the room. This is done by reaching the tile adjacent to the door.
- The human makes noise while moving, but is silent if crouches.
- Crouching makes movement 2x slower. If takes one second to move between 2 adjacent tiles, moving while crouching takes 2 seconds.
- The passage of time is represented with a turn-based system. Each turn represents the same amount of time (eg: one sencond)
- There is a monster in the room. The monster is blind, but can hear very well.
- The monster starts at the tile adjacent to the door.
- The monster is searching for the human. Will go to any tile where there is sound, at twice the walking speed the human has.
- If the monster is in an adjacent tile with the human, will hear the heartbeat and localize it immediatly. Doing so will attack and kill the human.
