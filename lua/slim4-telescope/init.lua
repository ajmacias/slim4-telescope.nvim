local M = {}

local telescope = require('telescope.pickers')
local finders = require('telescope.finders')
local conf = require('telescope.config').values
local actions = require('telescope.actions')
local actions_state = require('telescope.actions.state')
local ts = vim.treesitter
local lang = require("vim.treesitter.language")

-- Asegurarse de que Tree-sitter para PHP esté disponible
lang.add("php")

local function extract_routes_from_php(filepath)
  -- Leer contenido del archivo
  local file = io.open(filepath, "r")
  if not file then
    print("No se pudo abrir el archivo: " .. filepath)
    return {}
  end

  local content = file:read("*a")
  file:close()

  -- Parsear contenido con Tree-sitter
  local parser = ts.get_string_parser(content, "php")
  local tree = parser:parse()[1]
  if not tree then
    print("No se pudo analizar el archivo: " .. filepath)
    return {}
  end

  local root = tree:root()

  -- Consulta Tree-sitter
  local query = ts.query.parse(
    "php",
    [[
      (member_call_expression
        object: (variable_name (name) @var)
        name: (name) @methodname
        arguments: (arguments
          (argument (string (string_content) @route))
          (argument
            (array_creation_expression
              (array_element_initializer
                (class_constant_access_expression
                  (name) @controller_class
                )
              )
              (array_element_initializer
                (string (string_content) @action)
              )
            )
          )
        )
      )
    ]]
  )

  -- Extraer resultados
  local results = {}
  for _, match, _ in query:iter_matches(root, content) do
    local methodname, route, controller_class, action

    for id, node in pairs(match) do
      local capture_name = query.captures[id]
      local text = ts.get_node_text(node, content)

      if capture_name == "methodname" then methodname = text end
      if capture_name == "route" then route = text end
      if capture_name == "controller_class" then controller_class = text end
      if capture_name == "action" then action = text end
    end

    if methodname and route and controller_class and action and controller_class ~= "class" then
      table.insert(results, {
        method = methodname,
        route = route,
        controller = controller_class,
        action = action,
      })
    end
  end

  return results
end

local function buscar_archivos_en_carpeta(carpeta, extension)
  local archivos = vim.fn.glob(carpeta .. "/*." .. extension, true, true)
  return archivos
end

local function obtener_rutas_slim(carpeta)
  local archivos = buscar_archivos_en_carpeta(carpeta, "php")
  local todas_las_rutas = {}

  for _, archivo in ipairs(archivos) do
    local rutas = extract_routes_from_php(archivo)
    for _, ruta in ipairs(rutas) do
      table.insert(todas_las_rutas, ruta)
    end
  end

  return todas_las_rutas
end

local function abrir_controlador(controlador, accion)
  local archivo_controlador = controlador:gsub("%.", "/") .. ".php"
  local ruta_busqueda = "fd -t f '^" .. archivo_controlador .. "$'"
  print("Ejecutando comando: " .. ruta_busqueda)

  -- Ejecuta fd para buscar el archivo
  local handle = io.popen(ruta_busqueda)
  local resultado = handle:read("*a")
  handle:close()

  local archivos = {}
  for linea in resultado:gmatch("[^\r\n]+") do
    table.insert(archivos, linea)
  end

  if #archivos > 0 then
    local archivo = archivos[1]
    print("Archivo encontrado: " .. archivo)
    vim.cmd("edit " .. archivo) -- Abre el archivo del controlador

    -- Usa Tree-sitter para buscar la función
    local ts = vim.treesitter
    local bufnr = vim.api.nvim_get_current_buf()
    local parser = ts.get_parser(bufnr, "php") -- Asegúrate de que Tree-sitter para PHP esté configurado
    local tree = parser:parse()[1]
    local root = tree:root()

    -- Busca la definición de la función usando una consulta
    local query = ts.query.parse(
      "php",
      [[
        (method_declaration
          name: (name) @function_name
        )
      ]]
    )

    for _, match in query:iter_matches(root, bufnr) do
      for id, node in pairs(match) do
        local capture_name = query.captures[id]
        local function_name = ts.get_node_text(node, bufnr)

        if capture_name == "function_name" and function_name == accion then
          local start_row, start_col, _, _ = node:range() -- Obtén la posición de inicio de la función
          vim.api.nvim_win_set_cursor(0, { start_row + 1, start_col + 1 }) -- Mueve el cursor a la posición
          return
        end
      end
    end

    print("Función no encontrada: " .. accion)
  else
    print("Controlador no encontrado usando fd: " .. archivo_controlador)
  end
end

function M.buscar_rutas_slim()
  local carpeta_rutas = "./routes"
  local rutas = obtener_rutas_slim(carpeta_rutas)

  if not rutas or #rutas == 0 then
    print("No se encontraron rutas Slim 4.")
    return
  end

  -- Preparar elementos para Telescope
  local items = {}
  for _, ruta in ipairs(rutas) do
    table.insert(items, {
      display = string.format("[%-4s] %-50s -> %s@%s", string.upper(ruta.method), ruta.route, ruta.controller, ruta.action),
      ruta = ruta.route,
      controlador = ruta.controller,
      action = ruta.action,
      method = ruta.method,
    })
  end

  -- Configurar Telescope
  telescope.new({}, {
    prompt_title = "Slim4 - Routes",
    finder = finders.new_table({
      results = items,
      entry_maker = function(entry)
        return {
          value = entry,
          display = entry.display,
          ordinal = entry.display,
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = actions_state.get_selected_entry().value
        abrir_controlador(selection.controlador, selection.action)
      end)
      return true
    end,
  }):find()
end

function M.buscar_modelos()
  require("telescope.builtin").find_files({
    prompt_title = "Slim4 - Models",
    cwd = './app/Models',
  })
end

function M.buscar_vistas()
  require("telescope.builtin").find_files({
    prompt_title = "Slim4 - Views",
    cwd = './resources/views',
  })
end

function M.setup()
  vim.api.nvim_create_user_command('Slim4routes', M.buscar_rutas_slim, { desc = "Buscar rutas Slim 4 con Telescope" })
  vim.api.nvim_create_user_command('Slim4models', M.buscar_modelos, { desc = "Buscar modelos Slim 4 con Telescope" })
  vim.api.nvim_create_user_command('Slim4views', M.buscar_vistas, { desc = "Buscar vistas Slim 4 con Telescope" })
end

return M

