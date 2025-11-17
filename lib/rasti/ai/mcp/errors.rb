module Rasti
  module AI
    module MCP

      # JSON-RPC oficiales
      JSON_RPC_PARSE_ERROR               = -32700
      JSON_RPC_INVALID_REQUEST           = -32600
      JSON_RPC_METHOD_NOT_FOUND          = -32601
      JSON_RPC_INVALID_PARAMS            = -32602
      JSON_RPC_INTERNAL_ERROR            = -32603

      # JSON-RPC rango de servidor (permitido)
      JSON_RPC_SERVER_ERROR              = -32000
      JSON_RPC_SERVER_NOT_FOUND          = -32001
      JSON_RPC_SERVER_UNAUTHORIZED       = -32002
      JSON_RPC_SERVER_FORBIDDEN          = -32003
      JSON_RPC_SERVER_RESOURCE_NOT_FOUND = -32004
      JSON_RPC_SERVER_RATE_LIMIT         = -32005

      # MCP (usos comunes)
      MCP_INVALID_ACCESS                 = -32001
      MCP_TOOL_ERROR                     = -32002
      MCP_FETCH_ERROR                    = -32003
      MCP_RESOURCE_NOT_FOUND             = -32004
      MCP_TIMEOUT                        = -32005

    end
  end
end