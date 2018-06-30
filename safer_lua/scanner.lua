--[[

	SaferLua [safer_lua]
	====================

	Copyright (C) 2018 Joachim Stolberg

	LGPLv2.1+
	See LICENSE.txt for more information

	scanner.lua:

]]--

local function trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

function safer_lua:word(ch, pttrn)
	local word = ""
	while ch:match(pttrn) do
		word = word .. ch
		self.pos = self.pos + 1
		ch = self.line:sub(self.pos, self.pos)
	end
	return word
end

function safer_lua:string(pttrn)
	self.pos = self.pos + 1
	local ch = self.line:sub(self.pos, self.pos)
	while not ch:match(pttrn) and self.pos < #self.line do
		self.pos = self.pos + 1
		ch = self.line:sub(self.pos, self.pos)
	end
	self.pos = self.pos + 1
	-- result is not needed
end

function safer_lua:scanner(text)
	local lToken = {}
	for idx, line in ipairs(text:split("\n")) do
		self.line = line
		self.pos = 1
		self.line = trim(self.line)
		self.line = self.line:split("--")[1]
		if self.line then
			-- devide line in tokens
			table.insert(lToken, idx)  -- line number
			while true do
				if self.pos > #self.line then break end
				local ch = self.line:sub(self.pos, self.pos)
				if ch:match("[%u%l_]") then                       -- identifier?
					table.insert(lToken, self:word(ch, "[%w_]"))
				elseif ch:match("[%d]") then  -- number?
					table.insert(lToken, self:word(ch, "[%d%xx]"))
				elseif ch:match("'") then                         -- string?
					self:string("'")
				elseif ch:match('"') then                         -- string?
					self:string('"')
				elseif ch:match("[%s]") then                      -- Space?
					self.pos = self.pos + 1
				elseif ch:match("[:{}]") then                     -- critical tokens?
					table.insert(lToken,ch)
					self.pos = self.pos + 1
				else
					self.pos = self.pos + 1
				end
			end
		end
	end
	return lToken
end

local InvalidKeywords = {
	["while"] = true, 
	["repeat"] = true, 
	["break"] = true, 
	["until"] = true, 
	["for"] = true, 
	["function"] = true,
	["_G"] = true,
	["__load"] = true,
	["__dump"] = true,
}

local InvalidChars = {
	[":"] = true,
	["{"] = true,
	["}"] = true,
}

function safer_lua:check(text, label, err_clbk)
	local lToken = self:scanner(text)
	local lineno = 0
	local errno = 0
	for idx,token in ipairs(lToken) do
		if type(token) == "number" then
			lineno = token
		elseif InvalidKeywords[token] then
			if token ~= "for" or lToken[idx + 3] ~= "in" or 
					lToken[idx + 5] ~= "next" then -- invalid for statement?
				err_clbk(label..lineno..": Invalid keyword '"..token.."'")
				errno = errno + 1
			end
		elseif InvalidChars[token] then
			err_clbk(label..lineno..": Invalid character '"..token.."'")
			errno = errno + 1
		end
	end
	return errno
end
