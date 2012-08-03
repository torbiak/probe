let s:height = 0
let s:matches = []
let s:max_height = 10
let s:location = 'botright'
let s:bufname = '--probe--'
let s:bufnr = -1
let s:selection_marker = '> '
let s:marker_length = len(s:selection_marker)
let s:winrestcmd = ''
let s:selected = 0
let s:prompt_input = ''
let s:prev_prompt_input = ''
let s:index = 0
let s:downtime_timeout = 50

function! probe#open(scan_func)
    unlet! s:scan_func
    let s:scan_func = a:scan_func
    let s:winrestcmd = winrestcmd() " TODO: Support older versions of vim.
    cal s:save_options()
    set timeout          " ensure mappings timeout
    set timeoutlen=0     " respond immediately to mappings
    set nohlsearch       " don't highlight search strings
    set noinsertmode     " don't make Insert mode the default
    set noshowcmd        " don't show command info on last line
    set report=9999      " don't show 'X lines changed' reports
    set sidescroll=0     " don't sidescroll in jumps
    set sidescrolloff=0  " don't sidescroll automatically
    set noequalalways    " don't auto-balance window sizes
    let &updatetime = s:downtime_timeout

    if s:bufnr == -1
        exe printf('silent! %s 1split %s', s:location, s:bufname)
        let s:bufnr = bufnr('%')
        cal s:set_local_options()
    else " still have the buffer from last time
        exe printf('silent! %s sbuffer %d', s:location, s:bufnr)
        resize 1
    endif

    " TODO syntax highlighting for matches

    " Always cleanup, regardless how the buffer is left.
    " (eg. <C-W q>, <C-W k>, etc)
    autocmd! * <buffer>'
    autocmd BufLeave <buffer> silent! probe#close()
    autocmd BufUnload <buffer> silent! probe#restore_vim_state()

    cal prompt#map_key('<c-n>', 'probe#select_next')
    cal prompt#map_key('<c-p>', 'probe#select_prev')
    cal prompt#map_key('<c-s>', 'probe#accept_split')
    cal prompt#map_key('<c-v>', 'probe#accept_vsplit')
    cal prompt#map_key('<F5>', 'probe#refresh_file_cache')
    cal prompt#map_key('<F6>', 'probe#noop')

    cal prompt#open({
        \ 'accept': function('probe#accept'),
        \ 'cancel': function('probe#close'),
        \ 'change': function('probe#on_prompt_change'),
    \ })
    let s:candidates = s:scan_func()
    let s:matches = s:candidates
    let s:selected = 0
    let s:index = 0
    cal s:print_matches()
    cal s:register_downtime_autocmd()
endfunction

function! s:register_downtime_autocmd()
    if !has('autocmd')
        return
    endif
    au CursorHold <buffer> cal s:find_matches_during_downtime()
endfunction

function! probe#noop()
endfunction

function! s:set_local_options()
    setlocal bufhidden=unload " unload buf when no longer displayed
    setlocal buftype=nofile   " buffer is not related to any file
    "setlocal nomodifiable     " prevent manual edits
    setlocal noswapfile       " don't create a swapfile
    setlocal nowrap           " don't soft-wrap
    setlocal nonumber         " don't show line numbers
    setlocal nolist           " don't use List mode (visible tabs etc)
    setlocal foldcolumn=0     " don't show a fold column at side
    setlocal foldlevel=99     " don't fold anything
    setlocal nocursorline     " don't highlight line cursor is on
    setlocal nospell          " spell-checking off
    setlocal nobuflisted      " don't show up in the buffer list
    setlocal textwidth=0      " don't hard-wrap (break long lines)
    if exists('+colorcolumn')
        setlocal colorcolumn=0
    endif
    if exists('+relativenumber')
        setlocal norelativenumber
    endif
endfunction


let s:timeoutlen = 0
let s:report = 0
let s:sidescroll = 0
let s:sidescrolloff = 0
let s:timeout = 0
let s:equalalways = 0
let s:hlsearch = 0
let s:insertmode = 0
let s:showcmd = 0

function! s:save_options()
    let s:timeoutlen = &timeoutlen
    let s:report = &report
    let s:sidescroll = &sidescroll
    let s:sidescrolloff = &sidescrolloff
    let s:timeout = &timeout
    let s:equalalways = &equalalways
    let s:hlsearch = &hlsearch
    let s:insertmode = &insertmode
    let s:showcmd = &showcmd
    let s:updatetime = &updatetime
endfunction

function! s:restore_options()
    let &timeoutlen = s:timeoutlen
    let &report = s:report
    let &sidescroll = s:sidescroll
    let &sidescrolloff = s:sidescrolloff
    let &timeout = s:timeout
    let &equalalways = s:equalalways
    let &hlsearch = s:hlsearch
    let &insertmode = s:insertmode
    let &showcmd = s:showcmd
    let &updatetime = s:updatetime
endfunction

function! probe#unload_buffer()
    " bunload closes the buffer's window as well, but if the only other buffer
    " is unlisted VIM will refuse to unload the probe buffer unless it's
    " already closed.
    silent quit " quit in case the only other buffer is unlisted.
    exe 'silent! bunload! ' . s:bufnr
endfunction

function! probe#restore_vim_state()
    cal s:restore_options()
    exe s:winrestcmd
endfunction

function! probe#close()
    cal probe#unload_buffer()
    cal probe#restore_vim_state()
    " Since prompt isn't being closed the status line needs to be cleared.
    redraw
    echo
endfunction

function! s:buflist()
    let buflist = []
    for i in range(tabpagenr('$'))
       call extend(buflist, tabpagebuflist(i + 1))
    endfor
    return buflist
endfunction

function! probe#accept()
    cal probe#close()
    cal s:open_file(s:matches[s:selected], '')
endfunction

function! probe#accept_split()
    cal probe#close()
    cal s:open_file(s:matches[s:selected], 'split')
endfunction

function! probe#accept_vsplit()
    cal probe#close()
    cal s:open_file(s:matches[s:selected], 'vsplit')
endfunction

function! s:open_file(filepath, split)
    let cmd =  'edit'
    if a:split ==? 'split' || &modified
        let cmd = 'split'
    endif
    if a:split ==? 'vsplit'
        let cmd = 'vsplit'
    endif

    cal s:select_appropriate_window()
    let filepath = escape(a:filepath, '\\|%# "')
    let filepath = fnamemodify(filepath, ':.')
    exe printf('%s %s', cmd, filepath)
endfunction

function! s:select_appropriate_window()
" select the first normal-ish window.
    let initial = winnr()
    while 1
        if &buflisted || &buftype !=? 'nofile'
            return
        endif
        wincmd w
        if initial == winnr()
            return " Give up after cycling through all the windows.
        endif
    endwhile
endfunction

let s:downtime_chunk_size = 500
function! s:find_matches_during_downtime()
    if len(s:prompt_input) == 0
        return
    endif
    let [fresh_matches, s:index] = s:match(s:prompt_input, s:candidates, s:index, -1, s:downtime_chunk_size)
    "echo printf('Got %d matches.', len(fresh_matches))
    cal extend(s:matches, fresh_matches)
    " Send a do-nothing key to restart the CursorHold timer.
    call feedkeys("\<F6>")
endfunction

function! s:update_matches()
    if len(s:prompt_input) >= len(s:prev_prompt_input)
        let s:matches = s:match(s:prompt_input, s:matches, 0, s:max_height, 0)[0]
    else
        let s:index = 0
        let s:matches = []
    endif
    if len(s:matches) < s:max_height
        let needed = s:max_height - len(s:matches)
        let [fresh_matches, s:index] = s:match(s:prompt_input, s:candidates, s:index, needed, 0)
        cal extend(s:matches, fresh_matches)
    endif

    let s:selected = 0
    cal s:print_matches()
endfunction

function! s:match(pattern, candidates, start, needed, size)
    let size = a:size == 0 ? len(a:candidates) : a:size
    let needed = a:needed < 0 ? len(a:candidates) : a:needed

    let pattern = a:pattern
    if stridx(pattern, ' ') != -1
        let pattern = substitute(pattern, ' \+', '.*', 'g')
    else
        let pattern = substitute(pattern, '\zs', '.*', 'g')
    endif

    let matches = []
    let i = a:start
    while i < len(a:candidates) && len(matches) < needed && i - a:start < size
        let candidate = a:candidates[i]
        if candidate =~? pattern
            cal add(matches, candidate)
        endif
        let i += 1
    endwhile
    return [matches, i]
endfunction


function! probe#on_prompt_change(prompt_input)
    let s:prev_prompt_input = s:prompt_input
    let s:prompt_input = a:prompt_input
    cal s:update_matches()
endfunction

function! probe#select_next()
    let s:selected = s:selected <= 0 ? 0 : s:selected - 1
    cal s:print_matches()
endfunction

function! probe#select_prev()
    let s:selected = s:selected >= s:height-1 ? s:height-1 : s:selected + 1
    cal s:print_matches()
endfunction

function! s:print_matches()
    silent %delete
    let s:height = min([len(s:matches), s:max_height])
    exe printf('resize %d', s:height)
    if empty(s:matches)
        cal setline(1, '-- NO MATCHES --')
        return
    endif

    let i = 1
    while i <= s:height
        let prefix = s:height-i == s:selected ? '> ' : '  '
        cal setline(i, prefix . s:matches[s:height-i])
        let i += 1
    endwhile
    cal cursor(s:height - s:selected, 1)
endfunction

let s:caches = {}
let s:cache_order = []
let s:max_cache_size = 10000
let s:max_depth = 15
let s:max_caches = 1
let s:cache_dir = expand('$HOME/.probe_cache')

function! s:rshash(string)
    " Robert Sedgwick's hash function from Algorithms in C.
    "
    " Escaping entire paths to use as cache filenames seemed tricky and ugly
    " and vim doesn't support bitwise operations, so multiplicative hashing
    " looked attractive.

    let b = 378551
    let a = 63689
    let hash = 0
    for c in split(a:string, '\zs')
        let hash = hash * a + char2nr(c)
        let a = a * b
    endfor
    return hash
endfunction

function! s:cache_filepath(dir)
    return printf('%s/%x', s:cache_dir, s:rshash(a:dir))
endfunction

function! s:save_cache(dir, files)
    if !isdirectory(s:cache_dir)
        cal mkdir(s:cache_dir)
    endif
    cal writefile(a:files, s:cache_filepath(a:dir))
endfunction

function! probe#scan_files()
    let dir = getcwd()
    " use cache if possible
    if has_key(s:caches, dir)
        return s:caches[dir]
    endif
    let cache_filepath = s:cache_filepath(dir)
    if g:probe_persist_cache && filereadable(cache_filepath)
        let s:caches[dir] = readfile(cache_filepath)
        return s:caches[dir]
    endif

    " init new cache
    if !has_key(s:caches, dir)
        let s:caches[dir] = []
        cal add(s:cache_order, dir)
    endif

    " pare caches
    if len(s:caches) > s:max_caches
        unlet s:caches[s:cache_order[0]]
        let s:cache_order = s:cache_order[1:]
    endif

    " recursively scan for files
    let s:caches[dir] = s:scan_files(dir, [], 0)

    " pare the current cache
    if len(s:caches[dir]) > s:max_cache_size
        let start = len(s:caches[dir]) - s:max_cache_size
        let s:caches[dir] = s:caches[dir][start:]
    endif

    if g:probe_persist_cache
        cal s:save_cache(dir, s:caches[dir])
    endif

    cal prompt#render()
    return s:caches[dir]
endfunction

function! probe#refresh_file_cache()
    let dir = getcwd()
    unlet s:caches[dir]
    cal delete(s:cache_filepath(dir))
    cal probe#scan_files()
    cal s:update_matches()
endfunction

function! s:scan_files(dir, files, current_depth)
    " ignore dirs past max_depth
    if a:current_depth > s:max_depth
        return
    endif

    " scan dir recursively
    redraw
    echo "Scanning " . a:dir
    for name in split(globpath(a:dir, '*', 1), '\n')
        if s:match_some(name, g:probe_ignore_files)
            continue
        endif
        if isdirectory(name)
            cal s:scan_files(name, a:files, a:current_depth+1)
            continue
        endif
        cal add(a:files, fnamemodify(name, ':.'))
    endfor

    return a:files
endfunction

function! s:match_some(str, patterns)
    for pattern in a:patterns
        if match(a:str, pattern) != -1
            return 1
        endif
    endfor
    return 0
endfunction
