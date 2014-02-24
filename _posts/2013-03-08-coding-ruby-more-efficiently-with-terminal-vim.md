---
date: 2013-03-08
layout: post
title: Coding ruby more efficiently with terminal vim
location: San Francisco
author: paul
tags:
- vim
- coding
- ruby
---

Thanks to a [great post by Chris Jones](http://www.mentby.com/Group/vim-discuss/vim-orgmode.html) (look for his post
dated Mon, 06 Feb 2012), I managed to configure my Xsession and terminal vim, running within xterm to be precise, to
properly handle `Shift-CR`, my preferred key-sequence for code completions.

So my `~/.bashrc` now reads:

```bash
# $HOME/.bashrc
# ...

if [ "$DISPLAY" ]; then # X-based environment
  # this allows us to map <S-CR> in Vim
  xmodmap -e "keysym Return = Return currency"
fi

# ...
```

My `~/.vimrc` now reads:

```vim
" $HOME/.vimrc
" ...

" Map the special currency symbol (see ~/.bashrc) to <S-CR>
imap ¤ <S-CR>

" ...
```

Now vim will correctly handle and process `<S-CR>`, e.g.:

```vim
" $HOME/.vim/after/ftplugin/ruby.vim

" Missing credits here... I can' recall where I picked this up
if !exists( "*EndToken" )
  function EndToken()
    let current_line = getline( '.' )
    let braces_at_end = '{\s*|\(,\|\s\|\w*|\s*\)\?$'
    if match( current_line, braces_at_end ) >= 0
      return '}'
    else
      return 'end'
    endif
  endfunction
endif

imap <S-CR> <ESC>:execute 'normal o' . EndToken()<CR>O
```

In insert mode, this allows us to type:

```ruby
if a == b # <- cursor here
```

hit `<S-CR>` (shift+enter) and have this completed to:

```ruby
if a == b
  # <- cursor here
end
```

Or alternatively:

```ruby
[1,2,3].each { |x| # <- cursor here
```

followed by `<S-CR>` would get translated to:

```ruby
[1,2,3].each { |x|
   # <- cursor here
}
```
