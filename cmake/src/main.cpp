#include "imgui.h"
#include "imgui_stdlib.h"
#include "imgui_impl_sdl2.h"
#include "imgui_impl_sdlrenderer2.h"
#include <stdio.h>
#include <format>
#include <SDL.h>
#include "serial.hpp"
#include "serial_port.hpp"
#include "imgui_log.hpp"
#include "csv_reader.hpp"

#define COLOR_ERROR ImVec4{255, 0, 0, 255}
#define COLOR_OK ImVec4{0, 255, 0, 255}
#define COLOR_WARN ImVec4{255, 255, 0, 255}

#define LOG_ERROR(logger, category, msg) (logger).AddLog("[error] [%s] %s\n", (category), (msg))
#define LOG_INFO(logger, category, msg) (logger).AddLog("[info] [%s] %s\n", (category), (msg))
#define LOG_WARNING(logger, category, msg) (logger).AddLog("[warning] [%s] %s\n", (category), (msg))
#define LOG_CATEGORY_UART "uart"
#define LOG_CATEGORY_CSV "csv"

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
    imgui_io.Fonts->AddFontFromFileTTF("../../res/CaskaydiaMonoNerdFontMono-Regular.ttf", 18.0f);

    // Setup Platform/Renderer backends
    ImGui_ImplSDL2_InitForSDLRenderer(window, renderer);
    ImGui_ImplSDLRenderer2_Init(renderer);

    // Application logic
    std::vector<std::string> port_list;
    size_t port_list_idx = 0;
    list_serial_ports(port_list);

    typedef int32_t data_t;
    std::string filename_weights = "../../weights.csv";
    std::string filename_data = "../../data.csv";
    std::string filename_result = "../../result.csv";
    std::vector<std::vector<data_t>> matrix_weights;
    std::vector<std::vector<data_t>> matrix_data;
    CSVReader::read_matrix(matrix_weights, filename_weights);
    CSVReader::read_matrix(matrix_data, filename_data);
    bool weights_loaded = false, data_loaded = false;

    

    AppLog log;

    auto load_matrix = [&](std::vector<std::vector<data_t>> &matrix, std::string &path, bool &loaded) {
        int res = CSVReader::read_matrix(matrix, path); 
        if(res > 0) LOG_ERROR(log, LOG_CATEGORY_CSV, std::format("failed to load file {}", path).c_str());
        else loaded = true;
    };

    load_matrix(matrix_weights, filename_weights, weights_loaded);
    load_matrix(matrix_data, filename_data, data_loaded);

    boost::asio::io_context asio_io;
    Serial uart(asio_io, port_list[port_list_idx], 9600);

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
                    if(ImGui::BeginTabItem(weights_loaded ? "Weights (Loaded)" : "Weights")) {
                        ImGui::InputText("Weights", &filename_weights);
                        ImGui::SameLine();
                        if(ImGui::Button("Read file"))
                            load_matrix(matrix_weights, filename_weights, weights_loaded);
                        
                        if(!matrix_weights.empty()) {
                            size_t n = matrix_weights.size();
                            size_t m = matrix_weights.begin()->size();
                            if(ImGui::BeginTable("table_matrix_upload", m, table_flags)) {
                                for(size_t row = 0; row < n; ++row) {
                                    ImGui::TableNextRow();
                                    for(size_t col = 0; col < m; ++col) {
                                        ImGui::TableSetColumnIndex(col);
                                        ImGui::PushID(row * m + col);
                                        ImGui::PushStyleColor(ImGuiCol_FrameBg, IM_COL32(0, 0, 0, 0));
                                        int el = static_cast<int>(matrix_weights[row][col]);
                                        ImGui::InputInt("##xx", &el, 0, 0);
                                        matrix_weights[row][col] = static_cast<data_t>(el);
                                        ImGui::PopStyleColor();
                                        ImGui::PopID();
                                    }
                                }
                                ImGui::EndTable();
                            }
                        }
                        else ImGui::TextColored(COLOR_WARN, "MATRIX EMPTY");
                        ImGui::EndTabItem();
                    }
                    if(ImGui::BeginTabItem(data_loaded ? "Data (Loaded)" : "Data")) {
                        ImGui::InputText("Data", &filename_data);
                        ImGui::SameLine();
                        if(ImGui::Button("Read file"))
                            load_matrix(matrix_data, filename_data, data_loaded);

                        if(!matrix_data.empty()) {
                            size_t n = matrix_data.size();
                            size_t m = matrix_data.begin()->size();
                            if(ImGui::BeginTable("table_matrix_upload", m, table_flags)) {
                                for(size_t row = 0; row < n; ++row) {
                                    ImGui::TableNextRow();
                                    for(size_t col = 0; col < m; ++col) {
                                        ImGui::TableSetColumnIndex(col);
                                        ImGui::PushID(row * m + col);
                                        ImGui::PushStyleColor(ImGuiCol_FrameBg, IM_COL32(0, 0, 0, 0));
                                        int el = static_cast<int>(matrix_data[row][col]);
                                        ImGui::InputInt("##xx", &el, 0, 0);
                                        matrix_data[row][col] = static_cast<data_t>(el);
                                        ImGui::PopStyleColor();
                                        ImGui::PopID();
                                    }
                                }
                                ImGui::EndTable();
                            }
                        }
                        else ImGui::TextColored(COLOR_WARN, "MATRIX EMPTY");
                        ImGui::EndTabItem();
                    }
                    ImGui::EndTabBar();
                }

                }


            if(ImGui::Button("Upload!")) {
                if(uart.is_open() && data_loaded && weights_loaded) {
                    boost::system::error_code ec;
                    ec = uart.send_packet<data_t>(0x02);
                    if(ec) LOG_ERROR(log, LOG_CATEGORY_UART, ec.what().c_str());
                    ec = uart.send_packet<data_t>(0x01, matrix_weights);
                    if(ec) LOG_ERROR(log, LOG_CATEGORY_UART, ec.what().c_str());
                    ec = uart.send_packet<data_t>(0x03);
                    if(ec) LOG_ERROR(log, LOG_CATEGORY_UART, ec.what().c_str());
                    ec = uart.send_packet<data_t>(0x01, matrix_data);
                    if(ec) LOG_ERROR(log, LOG_CATEGORY_UART, ec.what().c_str());
                    ec = uart.send_packet<data_t>(0x04);
                    if(ec) LOG_ERROR(log, LOG_CATEGORY_UART, ec.what().c_str());
                    LOG_INFO(log, LOG_CATEGORY_UART, std::format("successfuly send data to {}", port_list[port_list_idx]).c_str());

                    LOG_INFO(log, LOG_CATEGORY_UART, "waiting for result...");
                    
                    std::vector<uint8_t> res;
                    // ec = uart.read(res, 8 * 4 * 4);
                    // if(ec) LOG_ERROR(log, LOG_CATEGORY_UART, ec.what().c_str());
                    // else for(auto& el : res) std::cout << el << std::endl;
                    // std::cout << res.size() << std::endl;
                    while(res.size() == 0) uart.read(res, 1);
                }
                else if(!uart.is_open()) 
                    LOG_ERROR(log, LOG_CATEGORY_UART, "serial port closed");
                else if(!data_loaded) 
                    LOG_ERROR(log, LOG_CATEGORY_CSV, "data matrix not loaded");
                else if(!weights_loaded) 
                    LOG_ERROR(log, LOG_CATEGORY_CSV, "weight matrix not loaded");
            }


            ImGui::SeparatorText("Download");
            ImGui::InputText("Result", &filename_data);
            ImGui::SameLine();
            if(ImGui::Button("Save"))
                load_matrix(matrix_data, filename_data, data_loaded);

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

