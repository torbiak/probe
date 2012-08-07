if exists('g:probe_loaded')
    "TODO
    "finish 
endif
let g:probe_loaded = 1

let s:default_ignore_files = []
if !exists('g:probe_ignore_files')
    let g:probe_ignore_files = []
endif
let g:probe_ignore_files = g:probe_ignore_files + s:default_ignore_files

if !exists('g:probe_persist_cache')
    let g:probe_persist_cache = 1
endif

command! Probe :cal probe#open(
    \ function('probe#file#scan'), 
    \ function('probe#file#open'),
    \ function('probe#file#refresh'))
command! ProbeFindFile :cal probe#open(
    \ function('probe#file#scan'), 
    \ function('probe#file#open'),
    \ function('probe#file#refresh'))
command! ProbeFindBuffer :cal probe#open(
    \ function('probe#buffer#scan'), 
    \ function('probe#buffer#open'),
    \ function('probe#buffer#refresh'))
