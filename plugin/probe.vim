if exists('g:probe_loaded')
    finish
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

command! ProbeFindFile :cal probe#open(function('probe#scan_files'))
