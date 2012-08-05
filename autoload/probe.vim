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
let s:index = 0 " s:candidates index
let s:candidates = []
let s:downtime_timeout = 50
let s:show_scores = 1

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

    " TODO statusline
    let s:scores = repeat([0], s:max_height) "TODO

    cal prompt#open({
        \ 'accept': function('probe#accept'),
        \ 'cancel': function('probe#close'),
        \ 'change': function('probe#on_prompt_change'),
    \ })
    let s:candidates = s:scan_func()
    let s:matches = s:candidates[: s:max_height-1]
    let s:selected = 0
    let s:index = s:max_height
    cal s:print_matches()
    "cal s:register_downtime_autocmd()
endfunction

function! s:register_downtime_autocmd()
    if !has('autocmd')
        return
    endif
    au CursorHold <buffer> cal s:find_matches_during_downtime()
endfunction

function! s:update_statusline()
    let percent_searched = float2nr((100.0 * s:index) / len(s:candidates))
    exe printf('setlocal stl=--probe--%%=%d\ matches\ out\ of\ %d\ (%d%%%%\ searched)',
        \ len(s:matches), len(s:candidates), percent_searched)
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

let s:path_separators = '/'
function! s:score_match(pattern, match)
" Score a match based on how close pattern characters match to path separators,
" other pattern characters, and the end of the match.
    let pattern = split(a:pattern, '\zs')
    let match = split(a:match, '\zs')
    let p_i = 0
    let m_i = 0
    let path_sep_dist = 0
    let char_match_dist = 100
    let score = 0
    while p_i < len(pattern) && m_i < len(match)
        let p_c = pattern[p_i]
        let m_c = match[m_i]

        let is_match = p_c == m_c

        if is_match
            let score += path_sep_dist == 0
            let score += char_match_dist == 0
            let score += m_i == (len(match) - 1)
        endif

        let is_path_sep = stridx(s:path_separators, m_c) != -1
        let path_sep_dist = is_path_sep ? 0 : path_sep_dist + 1
        let char_match_dist = is_match ? 0 : char_match_dist + 1
        let m_i += 1
        let p_i += is_match
    endwhile
    return score
endfunction

function! s:sort_matches_by_score(matches)
    let rankings = []
    for match in a:matches
        let score = s:score_match(s:prompt_input, match)
        cal add(rankings, [score, match])
    endfor
    let sorted = []
    let s:scores = []
    for pair in sort(rankings, function('s:ranking_compare'))
        cal add(sorted, pair[1])
        cal add(s:scores, pair[0])
    endfor
    return sorted
endfunction

function! s:ranking_compare(a, b)
    return a:b[0] - a:a[0]
endfunction

let s:match_cache = {}
let s:match_cache_order = []
let s:max_match_cache_size = 100
function! s:update_matches()
    if has_key(s:match_cache, s:prompt_input)
        let [s:matches, s:index] = s:match_cache[s:prompt_input]
    else
        cal s:find_new_matches()
    endif

    if len(s:prompt_input) > 0
        let s:match_cache[s:prompt_input] = [s:matches, s:index]
        cal add(s:match_cache_order, s:prompt_input)
    endif
    if len(s:match_cache) > s:max_match_cache_size
        unlet s:match_cache[s:match_cache_order[0]]
        let s:match_cache_order = s:match_cache_order[1:]
    endif

    let s:selected = 0
    let s:matches = s:sort_matches_by_score(s:matches)
    cal s:print_matches()
endfunction

function! s:find_new_matches()
    if len(s:prompt_input) >= len(s:prev_prompt_input)
        " See if the old matches are still valid.
        let s:matches = s:match(s:prompt_input, s:matches, 0, s:max_height)[0]
    else
        " Search is wider, so we need to go through all the candidates again.
        let s:index = 0
        let s:matches = []
    endif
    if len(s:matches) < s:max_height
        " Find any needed new matches.
        let needed = s:max_height - len(s:matches)
        let [fresh_matches, s:index] = s:match(s:prompt_input, s:candidates, s:index, needed)
        cal extend(s:matches, fresh_matches)
    endif
endfunction

function! s:match(pattern, candidates, start, needed)
    let needed = a:needed < 0 ? len(a:candidates) : a:needed

    let pattern = a:pattern
    if stridx(pattern, ' ') != -1
        let pattern = substitute(pattern, ' \+', '.*', 'g')
    else
        let pattern = substitute(pattern, '\zs', '.*', 'g')
    endif

    let matches = []
    let i = a:start
    while i < len(a:candidates) && len(matches) < needed
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
        let match = s:matches[s:height - i]
        let score = s:scores[s:height - i]
        if s:show_scores
            let line = printf('%s%d %s', prefix, score, match)
        else
            let line = prefix . match
        endif
        cal setline(i, line)
        let i += 1
    endwhile
    cal cursor(s:height - s:selected, 1)
    cal s:update_statusline()
endfunction

let s:file_caches = {}
let s:file_cache_order = []
let s:max_file_cache_size = 30000
let s:max_depth = 15
let s:max_file_caches = 1
let s:file_cache_dir = expand('$HOME/.probe_cache')

" Escaping entire paths to use as cache filenames seemed tricky and ugly
" and vim doesn't support bitwise operations, so multiplicative hashing
" looked attractive.
function! s:rshash(string)
    " Robert Sedgwick's hash function from Algorithms in C.

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
    return printf('%s/%x', s:file_cache_dir, s:rshash(a:dir))
endfunction

function! s:save_cache(dir, files)
    if !isdirectory(s:file_cache_dir)
        cal mkdir(s:file_cache_dir)
    endif
    cal writefile(a:files, s:cache_filepath(a:dir))
endfunction

function! probe#scan_files()
    let dir = getcwd()
    " use cache if possible
    if has_key(s:file_caches, dir)
        return s:file_caches[dir]
    endif
    let cache_filepath = s:cache_filepath(dir)
    if g:probe_persist_cache && filereadable(cache_filepath)
        let s:file_caches[dir] = readfile(cache_filepath)
        return s:file_caches[dir]
    endif

    " init new cache
    if !has_key(s:file_caches, dir)
        let s:file_caches[dir] = []
        cal add(s:file_cache_order, dir)
    endif

    " pare caches
    if len(s:file_caches) > s:max_file_caches
        unlet s:file_caches[s:file_cache_order[0]]
        let s:file_cache_order = s:file_cache_order[1:]
    endif

    " recursively scan for files
    let s:file_caches[dir] = s:scan_files(dir, [], 0)

    if g:probe_persist_cache
        cal s:save_cache(dir, s:file_caches[dir])
    endif

    cal prompt#render()
    return s:file_caches[dir]
endfunction

function! probe#refresh_file_cache()
    let dir = getcwd()
    unlet! s:file_caches[dir]
    cal delete(s:cache_filepath(dir))
    let s:match_cache = {}
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
        if len(a:files) >= s:max_file_cache_size
            break
        endif
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
