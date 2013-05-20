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

if !exists('g:probe_cache_repo_branches')
    let g:probe_cache_repo_branches = 1
endif

if !exists('g:probe_max_height')
    let g:probe_max_height = 10
endif

if !exists('g:probe_reverse_sort')
    let g:probe_reverse_sort = 0
endif

if !exists('g:probe_window_location')
    let g:probe_window_location = 'botright'
endif

if !exists('g:probe_scoring_threshold')
    let g:probe_scoring_threshold = 400
endif

if !exists('g:probe_use_wildignore')
    let g:probe_use_wildignore = 0
endif

if !exists('g:probe_mappings')
    let g:probe_mappings = {}
endif

command! -bar Probe call probe#file#find_in_repo()
command! ProbeFindFile call probe#file#find()
command! ProbeFindInRepo call probe#file#find_in_repo()
command! ProbeFindBuffer call probe#buffer#find()

function! <SID>ProbeClearCache()
    Probe
    cal g:Probe_clear_cache()
    cal probe#close()
endfunction
command! ProbeClearCache call <SID>ProbeClearCache()


if !hasmapto(':Probe<CR>')
  silent! nnoremap <unique> <silent> <Leader>f :Probe<CR>
endif

if !hasmapto(':ProbeFindBuffer<CR>')
  silent! nnoremap <unique> <silent> <Leader>b :ProbeFindBuffer<CR>
endif
