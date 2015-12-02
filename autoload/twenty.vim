let s:save_cpo = &cpo
set cpo&vim

let s:STATE_LOOP     = 1
let s:STATE_FINISH   = 2

let s:TITLE_LINE = 2
let s:HOWTO_LINE = 4
let s:REMAIN_LINE = 6
let s:TIME_LINE = 7
let s:STATUS_LINE = 8
let s:GAME_LINE = 10
let s:GAME_OFFSET = 3 " > 0
let s:POS_LIMIT = 5
let s:HIGH_SCORE_LINE = s:GAME_LINE + 7

" board takes value between 2 and 9
let s:field = 
      \[[2,3,4,5,6],
      \ [2,3,4,5,6],
      \ [2,3,4,5,6],
      \ [2,3,4,5,6],
      \ [2,3,4,5,6]]

" get 1 if already passed
let s:path_buffer = 
      \[[0,0,0,0,0],
      \ [0,0,0,0,0],
      \ [0,0,0,0,0],
      \ [0,0,0,0,0],
      \ [0,0,0,0,0]]

" cursor positions(0..4) and state(0..1)
let s:pos_x = 0
let s:pos_y = 0
let s:state_selected = 0

" record times
let s:high_score = 0
let s:record_time = 0

" remain
let s:remain = 0

" rand
" let s:RAND_MAX 32767
let s:seed = 0
function! s:Srand(seed)
  let s:seed = a:seed
endfunction
function! s:Rand()
  let s:seed = s:seed * 214013 + 2531011
  return (s:seed < 0 ? s:seed - 0x80000000 : s:seed) / 0x10000 % 0x8000
endfunction

function! s:stage_init() abort
  " open new buffer
  silent edit `='== =Twenty =='`
  silent normal! gg0
  silent only!
  setlocal buftype=nowrite
  setlocal noswapfile
  setlocal bufhidden=wipe
  setlocal buftype=nofile
  setlocal nonumber
  setlocal nolist
  setlocal nowrap
  setlocal nocursorline
  setlocal nocursorcolumn

  syn match path_char "_[2-9]_"
  hi path_char ctermfg=black ctermbg=green guifg=black guibg=green
  syn match cur_char "\*[2-9]\*"
  hi cur_char ctermfg=black ctermbg=yellow guifg=black guibg=yellow
  " clear whole screen
  let ww = winwidth('.')  " window width
  let wh = winheight('.') " window height
  let sh = 20 " stage height

  " fill screen
  for i in range(1, wh)
    call setline(i, repeat(' ', ww + 10))
  endfor
 
  " draw text
  call setline(s:TITLE_LINE, ' *** =Twenty *** ')
  call setline(s:HOWTO_LINE, '[hjkl]: move, v: select, d: twenty')
  call setline(s:HOWTO_LINE+1, ' q: quit, r: retry')

  let s:remain = 20
  call s:set_remain(s:remain)
  call s:set_time(0)
  call s:set_status('make just 20!')
  call setline(s:GAME_LINE,
        \      repeat(' ', s:GAME_OFFSET-1) . 
        \      repeat('===', s:POS_LIMIT) . '==')
  call setline(s:GAME_LINE + 6,
        \      repeat(' ', s:GAME_OFFSET-1) . 
        \      repeat('===', s:POS_LIMIT) . '==')
  call s:set_high_score(s:high_score)
  let s:state_selected = 0

  call s:Srand(localtime())
  "init field
  for i in range(0,4)
    for j in range(0,4)
      let s:path_buffer[i][j] = 0
      let s:field[i][j] = s:Rand() % 8 + 2
    endfor
  endfor
  redraw
endfunction

function! s:reset() abort
  bdelete
endfunction
             
" clear and update board
function! s:submit_and_update() abort
  let l:sum = 0
  for i in range(0,4)
    for j in range(0,4)
      if s:path_buffer[i][j] == 1
        let s:path_buffer[i][j] = 0
        let l:sum += s:field[i][j]
        let s:field[i][j] = s:Rand() % 8 + 2
      endif
    endfor
  endfor
  if l:sum == 20
    call s:set_status('=Twenty !!!')
    let s:remain -= 1
    call s:set_remain(s:remain)
  else
    call s:set_status(l:sum . ' is not Twenty')
  endif
endfunction

function! s:set_remain(remain)
  call setline(s:REMAIN_LINE, ' Remain: ' . a:remain)
endfunction

function! s:set_time(time)
  call setline(s:TIME_LINE, ' Time  : ' . printf("%3.2f",a:time))
endfunction

function! s:set_status(status)
  call setline(s:STATUS_LINE, ' Status: ' . a:status)
endfunction

function! s:set_high_score(high_score)
  call setline(s:HIGH_SCORE_LINE, 
        \ ' High Score: ' . printf("%3.2f",a:high_score))
endfunction

function! s:draw_path() abort
  for y in range(0, 4)
    let l:rowstr = ''
    for x in range(0, 4)
      if s:path_buffer[y][x] != 0
        let l:rowstr = l:rowstr . '_' . s:field[y][x] . '_'
      else
        let l:rowstr = l:rowstr . ' ' . s:field[y][x] . ' '
      endif
    endfor
    let l:py = s:GAME_LINE + 1 + y
    let l:line = getline(l:py)
    let l:line = l:line[:(s:GAME_OFFSET-1)] . rowstr . l:line[(s:GAME_OFFSET+15):]
    call setline(l:py, l:line)
  endfor
endfunction

function! s:move(dx,dy) abort
  if s:state_selected
    if s:check_path(s:pos_x + a:dx,s:pos_y + a:dy)
      let s:path_buffer[s:pos_y][s:pos_x] = 1
      let s:pos_x += a:dx
      let s:pos_y += a:dy
    endif
  else
    let s:pos_x += a:dx
    let s:pos_y += a:dy
  endif
endfunction

function! s:draw_pos() abort
  let px = s:pos_x * 3 + s:GAME_OFFSET
  let py = s:GAME_LINE + 1 + s:pos_y
  let l = getline(py)
  let l = l[:px-1] . '*' . l[px+1] . '*' . l[px+3:]
  call setline(py, l)
endfunction

function! s:draw_nums() abort
  let px = s:pos_x * 3 + s:GAME_OFFSET
  let py = s:GAME_LINE + 1 + s:pos_y
  for i in range(1, 5)
    " draw frame and nums
    let row = s:field[i - 1]
    call setline(i + s:GAME_LINE, 
          \ repeat(' ', s:GAME_OFFSET - 1) . '=' .
          \ join([' ', join(row,'  '), ' '], '')
          \ . '=')
  endfor
endfunction

function! s:check_path(px, py) abort
  if s:path_buffer[a:py][a:px] == 0
    return 1
  else
    return 0
  endif
endfunction

function! s:loop()
  call s:stage_init()
  let state = s:STATE_LOOP
  let rt = reltime()
  let retry = 0
  while 1
    " check status
    if s:remain <= 0
      let state = s:STATE_FINISH
    endif

    let c = getchar(0)
    " quit game
    if c == 27 || c == 113 " Esc, q
      break
    endif

    " retry game
    if c == 114 " r to retry
      let retry = 1
      break
    endif

    if c == 104 && s:pos_x > 0 " h
      call s:move(-1,0)
    endif

    if c == 106 && s:pos_y < s:POS_LIMIT-1 " j
      call s:move(0,1)
    endif

    if c == 107 && s:pos_y > 0 " k
      call s:move(0,-1)
    endif

    if c == 108 && s:pos_x < s:POS_LIMIT-1 " l
      call s:move(1,0)
    endif

    if state == s:STATE_LOOP
      if c == 118 && s:state_selected != 1 " v
        let s:state_selected = 1
      endif

      if c == 100 && s:state_selected != 0  " d
        let s:state_selected = 0
        let s:path_buffer[s:pos_y][s:pos_x] = 1
        call s:submit_and_update()
      endif
      "draw cursor
      call s:draw_nums()
      call s:draw_path()
      call s:draw_pos()
    
      let dt = str2float(reltimestr(reltime(rt))) 
      call s:set_time(dt)
      sleep 10m
    else
      if s:high_score > dt
        let s:high_score = dt
        call s:set_high_score(s:high_score)
      endif
      sleep 10m
    endif
    redraw
  endwhile
  call s:reset()
  return retry
endfunction

function! twenty#start() abort
  let s:high_score = 9999
  while s:loop()
  endwhile
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
