local request = require("http.request")
local json = require("dkjson")

local M = {}

M.Suffix = {
  -- linuxdo_space is semantic rather than literal: bindings resolve against
  -- "<owner_username>.linuxdo.space" after the ready event provides
  -- owner_username.
  linuxdo_space = "linuxdo.space",
}

local function class(name)
  local c = {}
  c.__index = c
  c.__name = name
  return c
end

local LinuxDoSpaceError = class("LinuxDoSpaceError")
function LinuxDoSpaceError:new(message, kind, inner)
  return setmetatable({ message = message, kind = kind or "generic", inner = inner }, self)
end
function LinuxDoSpaceError:__tostring()
  return string.format("%s(%s): %s", self.__name, self.kind, self.message)
end

local function AuthenticationError(message, inner)
  return LinuxDoSpaceError:new(message, "authentication", inner)
end

local function StreamError(message, inner)
  return LinuxDoSpaceError:new(message, "stream", inner)
end

M.LinuxDoSpaceError = LinuxDoSpaceError
M.AuthenticationError = AuthenticationError
M.StreamError = StreamError

local MailBox = class("MailBox")
function MailBox:new(opts)
  local o = {
    mode = opts.mode,
    suffix = opts.suffix,
    allow_overlap = opts.allow_overlap,
    prefix = opts.prefix,
    pattern = opts.pattern,
    address = opts.prefix and (opts.prefix .. "@" .. opts.suffix) or nil,
    _unbind = opts.unbind,
    _closed = false,
    _activated = false,
    _queue = {},
  }
  return setmetatable(o, self)
end

function MailBox:listen(callback)
  if self._closed then
    error("mailbox is already closed")
  end
  self._activated = true
  while not self._closed do
    if #self._queue > 0 then
      local msg = table.remove(self._queue, 1)
      callback(msg)
    else
      if self._client_closed then
        return
      end
    end
  end
end

function MailBox:close()
  if self._closed then
    return
  end
  self._closed = true
  self._unbind()
end

function MailBox:_enqueue(msg)
  if self._closed or not self._activated then
    return
  end
  self._queue[#self._queue + 1] = msg
end

local Client = class("Client")

local function base64_decode(value)
  local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  local lookup = {}
  for i = 1, #alphabet do
    lookup[alphabet:sub(i, i)] = i - 1
  end

  local cleaned = value:gsub("%s+", "")
  if cleaned == "" or (#cleaned % 4) ~= 0 then
    return nil, "invalid base64 length"
  end

  local out = {}
  local i = 1
  while i <= #cleaned do
    local a = cleaned:sub(i, i)
    local b = cleaned:sub(i + 1, i + 1)
    local c = cleaned:sub(i + 2, i + 2)
    local d = cleaned:sub(i + 3, i + 3)
    local av = lookup[a]
    local bv = lookup[b]
    local cv = c == "=" and nil or lookup[c]
    local dv = d == "=" and nil or lookup[d]
    if av == nil or bv == nil or (c ~= "=" and cv == nil) or (d ~= "=" and dv == nil) then
      return nil, "invalid base64 character"
    end

    local first = av * 4 + math.floor(bv / 16)
    out[#out + 1] = string.char(first)
    if c ~= "=" then
      local second = (bv % 16) * 16 + math.floor(cv / 4)
      out[#out + 1] = string.char(second)
    end
    if d ~= "=" and c ~= "=" then
      local third = (cv % 4) * 64 + dv
      out[#out + 1] = string.char(third)
    end
    i = i + 4
  end

  return table.concat(out), nil
end

local function is_local_host(host)
  return host == "localhost" or host == "127.0.0.1" or host == "::1" or host:match("%.localhost$")
end

local function normalize_base_url(v)
  local value = (v or ""):gsub("%s+$", ""):gsub("^%s+", ""):gsub("/+$", "")
  if value == "" then
    error("base_url must not be empty")
  end
  local scheme, host = value:match("^(https?)://([^/]+)")
  if not scheme or not host then
    error("base_url must include scheme and host")
  end
  if scheme ~= "https" and scheme ~= "http" then
    error("base_url must use http or https")
  end
  if scheme == "http" and not is_local_host(host:lower()) then
    error("non-local base_url must use https")
  end
  return value
end

function Client.new(opts)
  opts = opts or {}
  local token = (opts.token or ""):gsub("%s+$", ""):gsub("^%s+", "")
  if token == "" then
    error("token must not be empty")
  end
  local o = {
    _token = token,
    _base_url = normalize_base_url(opts.base_url or "https://api.linuxdo.space"),
    _bindings = {},
    _full_callbacks = {},
    _owner_username = nil,
    _closed = false,
  }
  return setmetatable(o, Client)
end

function Client:listen(callback)
  self._full_callbacks[#self._full_callbacks + 1] = callback
end

function Client:bind(opts)
  opts = opts or {}
  local prefix = opts.prefix
  local pattern = opts.pattern
  local has_prefix = prefix and prefix:gsub("%s", "") ~= ""
  local has_pattern = pattern and pattern:gsub("%s", "") ~= ""
  if (has_prefix and has_pattern) or (not has_prefix and not has_pattern) then
    error("exactly one of prefix or pattern must be provided")
  end
  local suffix = (opts.suffix or M.Suffix.linuxdo_space):lower()
  local mode = has_prefix and "exact" or "pattern"
  local normalized_prefix = has_prefix and prefix:lower() or nil
  local regex = has_pattern and ("^" .. pattern .. "$") or nil
  local allow_overlap = opts.allow_overlap and true or false

  local binding = {}
  local mailbox = MailBox:new({
    mode = mode,
    suffix = suffix,
    allow_overlap = allow_overlap,
    prefix = normalized_prefix,
    pattern = pattern,
    unbind = function()
      local chain = self._bindings[suffix] or {}
      local next_chain = {}
      for i = 1, #chain do
        if chain[i] ~= binding then
          next_chain[#next_chain + 1] = chain[i]
        end
      end
      if #next_chain == 0 then
        self._bindings[suffix] = nil
      else
        self._bindings[suffix] = next_chain
      end
    end,
  })

  binding.mode = mode
  binding.suffix = suffix
  binding.allow_overlap = allow_overlap
  binding.prefix = normalized_prefix
  binding.regex = regex
  binding.mailbox = mailbox
  self._bindings[suffix] = self._bindings[suffix] or {}
  table.insert(self._bindings[suffix], binding)
  return mailbox
end

local function parse_mail_message(payload)
  local recipients = {}
  local src = payload.original_recipients or {}
  for i = 1, #src do
    local v = tostring(src[i]):lower()
    if v ~= "" then
      recipients[#recipients + 1] = v
    end
  end
  local raw_message_base64 = tostring(payload.raw_message_base64 or "")
  if raw_message_base64 == "" then
    error(StreamError("mail event did not include raw_message_base64"))
  end
  local raw_bytes, decode_error = base64_decode(raw_message_base64)
  if raw_bytes == nil then
    error(StreamError("mail event contained invalid base64 message data", decode_error))
  end
  local raw = raw_bytes
  return {
    sender = tostring(payload.original_envelope_from or ""),
    recipients = recipients,
    received_at = tostring(payload.received_at or ""),
    raw = raw,
    raw_bytes = raw_bytes,
  }
end

function Client:route(message)
  local address = tostring(message.address or ""):lower()
  local local_part, suffix = address:match("^([^@]+)@(.+)$")
  if not local_part or not suffix then
    return {}
  end
  local chain = self._bindings[suffix]
  if chain == nil and self._owner_username ~= nil then
    local semantic_suffix = self._owner_username .. "." .. M.Suffix.linuxdo_space
    if suffix == semantic_suffix then
      chain = self._bindings[M.Suffix.linuxdo_space]
    end
  end
  chain = chain or {}
  local out = {}
  for i = 1, #chain do
    local binding = chain[i]
    local matched = false
    if binding.mode == "exact" then
      matched = binding.prefix == local_part
    else
      matched = local_part:match(binding.regex) ~= nil
    end
    if matched then
      out[#out + 1] = binding.mailbox
      if not binding.allow_overlap then
        break
      end
    end
  end
  return out
end

function Client:close()
  if self._closed then
    return
  end
  self._closed = true
  for _, chain in pairs(self._bindings) do
    for i = 1, #chain do
      chain[i].mailbox._client_closed = true
      chain[i].mailbox:close()
    end
  end
  self._bindings = {}
end

function Client:start()
  if self._closed then
    return
  end
  local stream_url = self._base_url .. "/v1/token/email/stream"
  local req = request.new_from_uri(stream_url)
  req.headers:upsert("authorization", "Bearer " .. self._token)
  req.headers:upsert("accept", "application/x-ndjson")

  local headers, stream = req:go()
  if not headers then
    error(StreamError("failed to open stream"))
  end

  local status = tonumber(tostring(headers:get(":status") or "0")) or 0
  if status == 401 or status == 403 then
    error(AuthenticationError("api token was rejected by backend"))
  end
  if status < 200 or status > 299 then
    error(StreamError("unexpected stream status code: " .. tostring(status)))
  end

  local buffer = ""
  for chunk in stream:each_chunk() do
    if self._closed then
      return
    end
    buffer = buffer .. tostring(chunk)
    while true do
      local newline_start, newline_end = buffer:find("\n", 1, true)
      if newline_start == nil then
        break
      end
      local line = buffer:sub(1, newline_start - 1):gsub("\r$", "")
      buffer = buffer:sub(newline_end + 1)
      if line ~= "" then
        local node, _, decode_error = json.decode(line, 1, nil)
        if node == nil then
          error(StreamError("received invalid JSON from stream", decode_error))
        end
        if type(node) == "table" then
          local t = tostring(node.type or "")
          if t == "ready" then
            local owner_username = tostring(node.owner_username or ""):gsub("%s+$", ""):gsub("^%s+", ""):lower()
            if owner_username == "" then
              error(StreamError("ready event did not include owner_username"))
            end
            self._owner_username = owner_username
          elseif t == "heartbeat" then
            -- Intentionally ignored.
          elseif t == "mail" then
            local parsed = parse_mail_message(node)
            local primary = parsed.recipients[1] or ""
            local msg = {
              address = primary,
              sender = parsed.sender,
              recipients = parsed.recipients,
              received_at = parsed.received_at,
              subject = "",
              message_id = nil,
              date = nil,
              from_header = "",
              to_header = "",
              cc_header = "",
              reply_to_header = "",
              from_addresses = {},
              to_addresses = {},
              cc_addresses = {},
              reply_to_addresses = {},
              text = parsed.raw,
              html = "",
              headers = {},
              raw = parsed.raw,
              raw_bytes = parsed.raw_bytes,
            }
            for i = 1, #self._full_callbacks do
              self._full_callbacks[i](msg)
            end
            local delivered = {}
            for i = 1, #parsed.recipients do
              local address = parsed.recipients[i]
              if not delivered[address] then
                delivered[address] = true
                local per_recipient = {}
                for k, v in pairs(msg) do
                  per_recipient[k] = v
                end
                per_recipient.address = address
                local targets = self:route({ address = address })
                for j = 1, #targets do
                  targets[j]:_enqueue(per_recipient)
                end
              end
            end
          end
        end
      end
    end
  end
end

M.Client = Client

return M
