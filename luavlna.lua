-- Module luavlna
-- code originally created by Patrick Gundlach
-- http://tex.stackexchange.com/q/27780/2891
-- The code was adapted for plain TeX and added some more features
-- 1. It is possible to turn this functionality only for some letters
-- 2. Code now works even for single letters after brackets etc.
--
local M = {}
local utf_match = unicode.utf8.match
local utf_char  = unicode.utf8.char
local alpha = string.char(37).."a" -- alpha class, entering 
-- percent char directly caused error
local alphas = {}
local match_char = function(x) return utf_match(x,alpha) end
local match_table = function(x, chars)
  local chars=chars or {} 
  return chars[x] 
end 
local singlechars = {} -- {a=true,i=true,z=true, v=true, u=true, o = true} 

local initials = {}

local main_language = nil

-- when main_language is set, we will not use lang info in the nodes, but 
-- main language instead
local get_language = function(lang)
  return main_language or lang
end

local set_main_language = function(lang)
  main_language = lang
end

local debug = false
local tex4ht = false
-- Enable processing only for certain letters
-- must be table in the {char = true, char2=true} form
local set_singlechars= function(lang,c)
  --print("Set single chars lua")
  print(type(lang), lang)
  if type(lang) == "table" then
    for _,l in pairs(lang) do
      print("language: ",l)
      singlechars[l] = c
    end
  else
    local lang = tonumber(lang)
    print("language: ",lang)
    -- for k,_ in pairs(c) do print(k) end
    singlechars[lang] = c
  end
end

local set_initials = function(lang,c)
  if type(lang) == "table" then
    for _,l in pairs(lang) do
      initials[l] = c
    end
  else
    local lang = tonumber(lang)
    initials[lang]=c
  end
end


local debug_tex4ht = function(head,p)
  --[[ local w = node.new("glyph")
  w.lang = tex.lang
  w.font = font.current()
  w.char = 64
  ]]
  --node.remove(head,node.prev(p))
  local w = node.new("whatsit", "special")
  w.data = "t4ht=<span style='background-color:red;width:2pt;'> </span>"
  return w, head
end

local debug_node = function(head,p)
  local w
  if tex4ht then
    w, head = debug_tex4ht(head,p)
  else
    w = node.new("whatsit","pdf_literal")                          
    w.data = "q 1 0 1 RG 1 0 1 rg 0 0 m 0 5 l 2 5 l 2 0 l b Q"           
  end
  node.insert_after(head,head,w)                                       
  node.insert_after(head,w,p)                                          
  -- return w
end


local set_debug= function(x)
  debug = x
end

local set_tex4ht = function()
  tex4ht = true
end

local insert_penalty = function(head)
  local p = node.new("penalty")                                           
  p.penalty = 10000                                                       
  local debug = debug or false
  if debug then
    local w = debug_node(head,p)
  else
    node.insert_after(head,head,p) 
  end
  return head
end

local replace_with_thin_space = function(head)
  local gluenode = node.new(node.id("glue"))
  local gluespec = node.new(node.id("glue_spec"))
  gluespec.width = tex.sp("0.2em")
  gluenode.spec = gluespec
  gluenode.next = head.next
  gluenode.prev = head.prev
  gluenode.next.prev = gluenode
  gluenode.prev.next = gluenode
  return gluenode
end

local is_alpha = function(c)
  local status = alphas[c]
  if not status then 
    status = utf_match(c, alpha)
    alphas[c] = status
  end
  return status
end

-- find whether letter is uppercase
local up_table = {}
local is_uppercase= function(c)
  if not is_alpha(c) then return false end
  local status = up_table[c]
  if status ~= nil then
    return status
  end
  status = unicode.utf8.upper(c) == c
  up_table[c] = status
  return status
end

local init_buffer = ""
local is_initial = function(c, lang)
  return is_uppercase(c)
end

local cut_off_end_chars = function(word, dot)
  local last = string.sub(word, -1)
  while word ~= "" and (not dot or last ~= ".") and not is_alpha(last) do
    word = string.sub(word, 1, -2) -- remove last char
    last = string.sub(word, -1)
  end
  return word
end

local part_until_non_alpha = function(word)
  for i = 1, #word do
    local c = word:sub(i,i)
    if not is_alpha(c) then
      word = string.sub(word, 1, i-1)
      break
    end
  end
  return word
end


function Set (list)
  local set = {}
  for _, l in ipairs(list) do set[l] = true end
  return set
end


local presi = (require "luavlna.presi")
local si = Set(require "luavlna.si")

local is_unit = function(word)
  word = part_until_non_alpha(word)
  if si[word] then
    return true
  end
  for _, prefix in pairs(presi) do
    s, e = string.find(word, prefix)
    if s == 1 then
      local unit = string.sub(word, e+1)
      if si[unit] then
        return true
      end
    end
  end
  return false
end

local predegrees = Set (require "luavlna.predegrees")
local sufdegrees = Set (require "luavlna.sufdegrees")

local function prevent_single_letter (head)                                   
  local singlechars = singlechars  -- or {} 
  -- match_char matches all single letters, but this method is abbandoned
  -- in favor of using table with enabled letters. With this method, multiple
  -- languages are supported
  local test_fn = match_table -- singlechars and match_table or match_char
  local space = true
  local init = false
  local anchor = head
  local wasnumber = false
  local word = ""
  while head do
    local id = head.id 
    local nextn = head.next
    local skip = node.has_attribute(head, luatexbase.attributes.preventsinglestatus) 
    if skip ~= 1  then 
      if id == 10 then
        if wasnumber then
          if word ~= "" then
            wasnumber = false
            word = cut_off_end_chars(word, false)
            if is_unit(word) then
              anchor = replace_with_thin_space(anchor)
              insert_penalty(anchor.prev)
            end
          end
        elseif tonumber(string.sub(word, -1)) ~= nil then
          wasnumber = true
        else
          word = cut_off_end_chars(word, true)
          if predegrees[word] then
            insert_penalty(head.prev)
          elseif sufdegrees[word] then
            insert_penalty(anchor.prev)
          end
        end
        space=true
        anchor = head
        word = ""
        init = is_initial " " -- reset initials
      elseif space==true and id == 37 and utf_match(utf_char(head.char), alpha) then -- a letter 
        local lang = get_language(head.lang)
        local char = utf_char(head.char)
        word = char
        init = is_initial(char,lang)
        local s = singlechars[lang] or {} -- load singlechars for node's lang
        --[[
        for k, n in pairs(singlechars) do
        for c,_ in pairs(n) do
        --print(type(k), c)
        end
        end
        --]]
        if test_fn(char, s) and nextn.id == 10 then    -- only if we are at a one letter word
          head = insert_penalty(head)
        end                                                                       
        space = false
        -- handle initials
        -- uppercase letter followed by period (code 46)
      elseif init and head.id == 37 and head.char == 46 and nextn.id == 10 then 
        head = insert_penalty(head)
      elseif head.id == 37 then
        local char = utf_char(head.char)
        word = word .. char
        init = is_initial(char, head.lang)
        -- hlist support
      elseif head.id == 0 then
        prevent_single_letter(head.head)
        -- vlist support
      elseif head.id == 1 then
        prevent_single_letter(head.head)
      end               
    end
    head = head.next                                                            
  end                                                                             
  return  true
end               

M.preventsingle = prevent_single_letter
M.singlechars = set_singlechars
M.initials    = set_initials
M.set_tex4ht  = set_tex4ht
M.debug = set_debug
M.predegrees = predegrees
M.sufdegrees = sufdegrees
M.presi = presi
M.si = si
M.set_main_language = set_main_language
return M
