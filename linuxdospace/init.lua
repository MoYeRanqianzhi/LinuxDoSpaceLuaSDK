local request = require("http.request")
local json = require("dkjson")

local M = {}

M.Suffix = {
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
  local raw_bytes = raw_message_base64
  local raw = raw_message_base64
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
  local chain = self._bindings[suffix] or {}
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

  for chunk in stream:each_chunk() do
    if self._closed then
      return
    end
    for line in tostring(chunk):gmatch("[^\r\n]+") do
      local ok, node = pcall(json.decode, line)
      if ok and node and type(node) == "table" then
        local t = tostring(node.type or "")
        if t == "mail" then
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
              local targets = self:route({ address = address })
              for j = 1, #targets do
                targets[j]:_enqueue(msg)
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
