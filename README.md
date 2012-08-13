TODO: Write a real README

--probe----o

Introduction
============
probe is a pure-Vimscript fuzzy finder, in the spirit of the command-t and
ctrl-p vim plugins. I didn't like that command-t needed ruby compiled into vim
or how ctrl-p ordered matches, and I found ctrl-p's code difficult to modify,
so I have combined the features I liked most about each.

To find a file under vim's current directory invoke the Probe command and enter
a subsequence of characters that exist in your target filepath. probe finds
files that match your query and ranks then according to a simple algorithm that
assigns points to characters that match immediately: after a path separator,
after another matched character, or before the end of the filepath. Because of
this ranking algorithm the two best approaches to finding files using probe are
to enter the first few characters of some path components as you work your way
towards your target, or to simply enter the filename if it's uncommon enough
with respect to other filepaths in the scope of the search.

I've tried to make probe work well when searching large numbers of files
(~100k). Because of this probe only finds as many matches as it needs to fill
the match window before it ranks and displays them. (TODO: add option for
window max height).

Key Mappings
============
* Previous match: C-p
* Next match: C-n

* Open current match: Enter
* Open in split: C-s
* Open in vsplit: C-v
* Cancel: C-c
* Refresh cache: F5

* Beginning of line: C-a
* End of line: C-e
* Delete to end of line: C-k
* Delete to beginning of line: C-u
* Cursor right: C-f or Right
* Cursor left: C-b or Left
* Delete: Del or C-d

Install
=======
The only sane installation method I'm aware of is to install Tim Pope's
Pathogen plugin and cloning this plugin's repository from github into
~/.vim/bundle.

Requirements
============
Haven't tested on windows yet. Backslashes in filepaths could be a problem.

I tried not to use vim's newer features. The whole point of writing a fuzzy
finder in vimscript was so that it would almost always just work.
TODO: Figure out when winrestcmd was added.

My goal is for any most vims past v6 to work, but so far I've only tested with
v7.3.

Unimplemented Features
======================
searching for a VCS meta-directory and using the VCS to get file information
    * allows searching an entire project without requiring vim's working
      directory to be the project's root
