#include "imgui.h"
#include "imgui_stdlib.h"
#include "imgui_impl_sdl2.h"
#include "imgui_impl_sdlrenderer2.h"
#include <format>
#include <SDL.h>
#include "serial.hpp"
#include "serial_port.hpp"
#include "imgui_log.hpp"
#include "csv_reader.hpp"
#include "datamatrix.hpp"
#include "utils.hpp"
#include "defines.hpp"

#if !SDL_VERSION_ATLEAST(2,0,17)
#error This backend requires SDL 2.0.17+ because of SDL_RenderGeometry() function
#endif

// Main code
int main(int, char**)
{
    SDL_LogSetAllPriority(SDL_LOG_PRIORITY_INFO);
    // Setup SDL
    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_TIMER | SDL_INIT_GAMECONTROLLER) != 0)
    {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Error: %s\n", SDL_GetError());
        return -1;
    }

    // From 2.0.18: Enable native IME.
#ifdef SDL_HINT_IME_SHOW_UI
    SDL_SetHint(SDL_HINT_IME_SHOW_UI, "1");
#endif

    // Create window with SDL_Renderer graphics context
    SDL_WindowFlags window_flags = (SDL_WindowFlags)(SDL_WINDOW_RESIZABLE | SDL_WINDOW_ALLOW_HIGHDPI);
    SDL_Window* window = SDL_CreateWindow("Systolic array interface", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, 1280, 720, window_flags);
    if (window == nullptr)
    {
        SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "Error: SDL_CreateWindow(): %s\n", SDL_GetError());
        return -1;
    }
    SDL_Renderer* renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_PRESENTVSYNC | SDL_RENDERER_ACCELERATED);
    if (renderer == nullptr)
    {
        SDL_LogError(SDL_LOG_CATEGORY_ERROR, "Error creating SDL_Renderer");
        return -1;
    }
    SDL_RendererInfo info;
    SDL_GetRendererInfo(renderer, &info);
    SDL_LogInfo(SDL_LOG_CATEGORY_RENDER, "Current SDL_Renderer: %s", info.name);

    // Setup Dear ImGui context
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO& imgui_io = ImGui::GetIO(); (void)imgui_io;
    imgui_io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;     // Enable Keyboard Controls
    imgui_io.ConfigFlags |= ImGuiConfigFlags_NavEnableGamepad;      // Enable Gamepad Controls

    // Setup windows
    ImGuiWindowFlags window_main_flags = ImGuiWindowFlags_NoCollapse 
                                        | ImGuiWindowFlags_NoMove 
                                        | ImGuiWindowFlags_NoDecoration
                                        | ImGuiWindowFlags_MenuBar;


    ImGuiWindowFlags window_settings_flags = ImGuiWindowFlags_NoCollapse 
                                            | ImGuiWindowFlags_NoMove;

    ImGuiWindowFlags window_upload_flags = ImGuiWindowFlags_NoCollapse 
                                            | ImGuiWindowFlags_NoMove;

    ImGuiTableFlags table_flags = ImGuiTableFlags_Borders | ImGuiTableFlags_RowBg;


    // Dear ImGui style
    ImGui::StyleColorsDark();
    uint8_t current_style = 0;

    // Setyp Dear ImGui font
    imgui_io.Fonts->AddFontFromFileTTF(DEFAULT_FILENAME_FONT, 18.0f);

    // Setup Platform/Renderer backends
    ImGui_ImplSDL2_InitForSDLRenderer(window, renderer);
    ImGui_ImplSDLRenderer2_Init(renderer);

    // Application logic
    std::vector<std::string> port_list;
    size_t port_list_idx = 0;
    list_serial_ports(port_list);

    Datamatrix<data_t> dweight(DEFAULT_FILENAME_WEIGHTS);
    Datamatrix<data_t> ddata(DEFAULT_FILENAME_DATA);
    Datamatrix<data_t> dresult(DEFAULT_FILENAME_RES);
    CSVReader::read_matrix(dweight.matrix, dweight.filename);
    CSVReader::read_matrix(ddata.matrix, ddata.filename);

    AppLog log;

    load_matrix<data_t>(log, dweight.matrix, dweight.filename, dweight.loaded);
    load_matrix<data_t>(log, ddata.matrix, ddata.filename, ddata.loaded);

    boost::asio::io_context asio_io;
    Serial uart(asio_io, port_list[port_list_idx], BAUDRATE);

    // Main loop
    bool done = false;
    while (!done)
    {
        SDL_Event event;
        while (SDL_PollEvent(&event))
        {
            ImGui_ImplSDL2_ProcessEvent(&event);
            if (event.type == SDL_QUIT)
                done = true;
            if (event.type == SDL_WINDOWEVENT && event.window.event == SDL_WINDOWEVENT_CLOSE && event.window.windowID == SDL_GetWindowID(window))
                done = true;
        }
        if (SDL_GetWindowFlags(window) & SDL_WINDOW_MINIMIZED)
        {
            SDL_Delay(10);
            continue;
        }

        // Start the Dear ImGui frame
        ImGui_ImplSDLRenderer2_NewFrame();
        ImGui_ImplSDL2_NewFrame();
        ImGui::NewFrame();


        // Application Interface
        const ImGuiViewport* main_viewport = ImGui::GetMainViewport();

        ImGui::SetNextWindowPos(ImVec2(main_viewport->Pos), ImGuiCond_Always);
        ImGui::SetNextWindowSize(ImVec2(main_viewport->Size), ImGuiCond_Always);

        ImGui::Begin("Main", nullptr, window_main_flags);

        {
            if(ImGui::BeginMenuBar())
            {
                if(ImGui::BeginMenu("Options"))
                {
                    if(ImGui::BeginMenu("Color scheme"))
                    {
                        if(ImGui::MenuItem("Dark", nullptr, current_style == 0)) { ImGui::StyleColorsDark(); current_style = 0; }
                        if(ImGui::MenuItem("Light", nullptr, current_style == 1)) { ImGui::StyleColorsLight(); current_style = 1; }
                        if(ImGui::MenuItem("Classic", nullptr, current_style == 2)) { ImGui::StyleColorsClassic(); current_style = 2; }
                        ImGui::EndMenu();
                    }

                    ImGui::EndMenu();
                }
                ImGui::EndMenuBar();
            }
        }

        {
            ImGui::BeginChild("Settings", ImVec2(300, 0), ImGuiChildFlags_Borders | ImGuiChildFlags_ResizeX, window_settings_flags);
            ImGui::SeparatorText("Settings");

            if(ImGui::Button("Update")) { port_list.clear(); list_serial_ports(port_list); }
            ImGui::SameLine();
            ImGui::SetNextItemWidth(ImGui::GetContentRegionAvail().x * 0.5);
            if(ImGui::BeginCombo("Serial Port", port_list.empty() ? "No serial ports available" : port_list[port_list_idx].c_str())) {
                for(size_t i = 0; i < port_list.size(); ++i) {
                    const bool is_selected = i == port_list_idx;
                    if(ImGui::Selectable(port_list[i].c_str(), is_selected))
                        port_list_idx = i;

                    if (is_selected) {
                        ImGui::SetItemDefaultFocus();
                    }
                }
                ImGui::EndCombo();
            }

            if(ImGui::Button("Open serial")) {
                uart.set_device(port_list[port_list_idx]);
                boost::system::error_code ec = uart.open();
                if(ec) LOG_ERROR(log, LOG_CATEGORY_UART, ec.what().c_str());
            }


            ImGui::SameLine();
            if(uart.is_open()) ImGui::TextColored(COLOR_OK, "OPEN");
            else ImGui::TextColored(COLOR_WARN, "CLOSED");

            ImGui::SeparatorText("Log");
            log.Draw("Log");

            ImGui::EndChild();
        }
        
        ImGui::SameLine();

        {
            ImGui::BeginChild("Upload", ImVec2(0, 0), ImGuiChildFlags_Borders, window_upload_flags);
            ImGui::SeparatorText("Upload");

            {
                if(ImGui::BeginTabBar("DataTabBar")) {
                    if(ImGui::BeginTabItem(dweight.loaded ? "Weights (Loaded)" : "Weights")) {
                        ImGui::InputText("Weights", &dweight.filename);
                        ImGui::SameLine();
                        if(ImGui::Button("Read file"))
                            load_matrix<data_t>(log, dweight.matrix, dweight.filename, dweight.loaded);
                        
                        if(!dweight.matrix.empty()) {
                            size_t n = dweight.get_h();
                            size_t m = dweight.get_w();
                            if(ImGui::BeginTable("table_matrix_upload", m, table_flags)) {
                                for(size_t row = 0; row < n; ++row) {
                                    ImGui::TableNextRow();
                                    for(size_t col = 0; col < m; ++col) {
                                        ImGui::TableSetColumnIndex(col);
                                        ImGui::PushID(row * m + col);
                                        ImGui::PushStyleColor(ImGuiCol_FrameBg, IM_COL32(0, 0, 0, 0));
                                        int el = static_cast<int>(dweight.matrix[row][col]);
                                        ImGui::InputInt("##xx", &el, 0, 0);
                                        dweight.matrix[row][col] = static_cast<data_t>(el);
                                        ImGui::PopStyleColor();
                                        ImGui::PopID();
                                    }
                                }
                                ImGui::EndTable();
                            }
                            ImGui::Text("Determined size [height x width]: %d x %d", n, m);
                        }
                        else ImGui::TextColored(COLOR_WARN, "MATRIX EMPTY");
                        ImGui::EndTabItem();
                    }
                    if(ImGui::BeginTabItem(ddata.loaded ? "Data (Loaded)" : "Data")) {
                        ImGui::InputText("Data", &ddata.filename);
                        ImGui::SameLine();
                        if(ImGui::Button("Read file"))
                            load_matrix<data_t>(log, ddata.matrix, ddata.filename, ddata.loaded);

                        if(!ddata.matrix.empty()) {
                            size_t n = ddata.get_h();
                            size_t m = ddata.get_w();
                            if(ImGui::BeginTable("table_matrix_upload", m, table_flags)) {
                                for(size_t row = 0; row < n; ++row) {
                                    ImGui::TableNextRow();
                                    for(size_t col = 0; col < m; ++col) {
                                        ImGui::TableSetColumnIndex(col);
                                        ImGui::PushID(row * m + col);
                                        ImGui::PushStyleColor(ImGuiCol_FrameBg, IM_COL32(0, 0, 0, 0));
                                        int el = static_cast<int>(ddata.matrix[row][col]);
                                        ImGui::InputInt("##xx", &el, 0, 0);
                                        ddata.matrix[row][col] = static_cast<data_t>(el);
                                        ImGui::PopStyleColor();
                                        ImGui::PopID();
                                    }
                                }
                                ImGui::EndTable();
                            }
                            ImGui::Text("Determined size [height x width]: %d x %d", n, m);
                        }
                        else ImGui::TextColored(COLOR_WARN, "MATRIX EMPTY");
                        ImGui::EndTabItem();
                    }
                    ImGui::EndTabBar();
                }

                }


            if(ImGui::Button("Upload!")) {
                if(uart.is_open() && dweight.loaded && ddata.loaded) {
                    dresult.resize(ddata.get_h(), dweight.get_w());

                    std::vector<uint8_t> packet; 
                    form_packet(ddata.matrix, dweight.matrix, packet); 
                    boost::system::error_code ec;
                    size_t bytes_sent = uart.write(packet, ec);
                    LOG_INFO(log, LOG_CATEGORY_UART, std::format("successfuly sent {} bytes to {}", bytes_sent, port_list[port_list_idx]).c_str());

                    LOG_INFO(log, LOG_CATEGORY_UART, "waiting for result...");
                    
                    std::vector<data_t> result;
                    result.resize(dresult.get_h() * dresult.get_w());
                    size_t bytes_read = uart.read(result, ec, UART_TIMEOUT);
                    if(ec == boost::asio::error::operation_aborted) 
                        LOG_ERROR(log, LOG_CATEGORY_UART, std::format("Timeout [{}] exceeded", UART_TIMEOUT).c_str());
                    else if(ec) 
                        LOG_ERROR(log, LOG_CATEGORY_UART, ec.what().c_str());

                    if(bytes_read != 0) {
                        LOG_INFO(log, LOG_CATEGORY_UART, std::format("{} bytes recieved", bytes_read).c_str());
                        for(size_t i = 0; i < result.size(); ++i)
                            dresult.matrix[static_cast<size_t>(std::floor(i / dresult.get_w()))][i % dresult.get_w()] = result[i];
                    }
                    else
                        LOG_WARNING(log, LOG_CATEGORY_UART, "No data recieved");

                }
                else if(!uart.is_open()) 
                    LOG_ERROR(log, LOG_CATEGORY_UART, "serial port closed");
                else if(!ddata.loaded) 
                    LOG_ERROR(log, LOG_CATEGORY_CSV, "data matrix not loaded");
                else if(!dweight.loaded) 
                    LOG_ERROR(log, LOG_CATEGORY_CSV, "weight matrix not loaded");
            }


            ImGui::SeparatorText("Download");
            ImGui::InputText("Result", &dresult.filename);
            ImGui::SameLine();
            if(ImGui::Button("Save"))
                save_matrix(log, dresult.matrix, dresult.filename);

            if(!dresult.matrix.empty()) {
                size_t n = dresult.get_h();
                size_t m = dresult.get_w();
                if(ImGui::BeginTable("table_matrix_upload", m, table_flags)) {
                    for(size_t row = 0; row < n; ++row) {
                        ImGui::TableNextRow();
                        for(size_t col = 0; col < m; ++col) {
                            ImGui::TableSetColumnIndex(col);
                            ImGui::PushID(row * m + col);
                            ImGui::Text(std::to_string(dresult.matrix[row][col]).c_str());
                            ImGui::PopID();
                        }
                    }
                    ImGui::EndTable();
                }
                ImGui::Text("Determined size [height x width]: %d x %d", n, m);
            }
            else ImGui::TextColored(COLOR_WARN, "MATRIX EMPTY");

            ImGui::EndChild();
        }

        ImGui::End();

        // ImGui::ShowDemoWindow();

        // Rendering
        ImGui::Render();
        SDL_RenderSetScale(renderer, imgui_io.DisplayFramebufferScale.x, imgui_io.DisplayFramebufferScale.y);
        SDL_RenderClear(renderer);
        ImGui_ImplSDLRenderer2_RenderDrawData(ImGui::GetDrawData(), renderer);
        SDL_RenderPresent(renderer);
    }

    // Cleanup
    ImGui_ImplSDLRenderer2_Shutdown();
    ImGui_ImplSDL2_Shutdown();
    ImGui::DestroyContext();

    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();

    return 0;
}

