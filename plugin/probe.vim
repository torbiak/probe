if exists('g:probe_loaded')
    "TODO
    "finish 
endif
let g:probe_loaded = 1

if !exists('g:probe_ignore_files')
    let g:probe_ignore_files = []
endif

if !exists('g:probe_cache_dir')
    let g:probe_cache_dir = expand('$HOME/.probe_cache')
endif

if !exists('g:probe_max_file_cache_size')
    let g:probe_max_file_cache_size = 100000
endif

if !exists('g:probe_max_height')
    let g:probe_max_height = 10
endif

"TODO
if !exists('g:probe_reverse_sort')
    let g:probe_reverse_sort = 0
endif

if !exists('g:probe_window_location')
    let g:probe_window_location = 'botright'
endif

if !exists('g:probe_scoring_threshold')
    let g:probe_scoring_threshold = 400
endif

if !exists('g:probe_mappings')
    let g:probe_mappings = {}
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

command! ProbeRefresh :cal probe#refresh_cache()

if !hasmapto(':Probe<CR>')
  silent! nnoremap <unique> <silent> <Leader>f :Probe<CR>
endif

if !hasmapto(':ProbeFindBuffer<CR>')
  silent! nnoremap <unique> <silent> <Leader>b :ProbeFindBuffer<CR>
endif
