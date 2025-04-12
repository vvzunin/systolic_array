#include "serial_port.hpp"

#ifdef __linux__
#include <glob.h>

void list_serial_ports(std::vector<std::string> &port_list)
{
    // Common serial port locations
    const char* patterns[] = {
        "/dev/ttyS*",    // Standard serial ports
        "/dev/ttyUSB*",   // USB-to-serial converters
        "/dev/ttyACM*",   // USB CDC ACM devices (e.g., Arduino)
        "/dev/ttyAMA*",   // AMBA serial ports (e.g., Raspberry Pi)
        nullptr
    };
    
    for (int i = 0; patterns[i] != nullptr; i++) {
        glob_t glob_result;
        if (glob(patterns[i], GLOB_TILDE, nullptr, &glob_result) == 0) {
            for (size_t j = 0; j < glob_result.gl_pathc; j++) {
                port_list.push_back(glob_result.gl_pathv[j]);
            }
            globfree(&glob_result);
        }
    }
}

#elif _WIN32

#include <windows.h>
#include <tchar.h>

void list_serial_ports(std::vector<std::string> &port_list)
{
    HKEY hKey;
    
    if (RegOpenKeyEx(HKEY_LOCAL_MACHINE, 
                    _T("HARDWARE\\DEVICEMAP\\SERIALCOMM"),
                    0,
                    KEY_READ,
                    &hKey) == ERROR_SUCCESS) {
        
        DWORD maxValueNameSize;
        DWORD maxValueDataSize;
        DWORD valuesCount;
        
        // Get the sizes needed
        RegQueryInfoKey(hKey, NULL, NULL, NULL, NULL, NULL, NULL,
                        &valuesCount, &maxValueNameSize, &maxValueDataSize,
                        NULL, NULL);
        
        // Allocate buffers
        std::vector<TCHAR> valueName(maxValueNameSize + 1);
        std::vector<BYTE> valueData(maxValueDataSize + 1);
        
        for (DWORD i = 0; i < valuesCount; i++) {
            DWORD nameSize = maxValueNameSize + 1;
            DWORD dataSize = maxValueDataSize + 1;
            DWORD type;
            
            if (RegEnumValue(hKey, i, &valueName[0], &nameSize,
                            NULL, &type, &valueData[0], &dataSize) == ERROR_SUCCESS) {
                
                if (type == REG_SZ) {
                    port_list.push_back(reinterpret_cast<char*>(&valueData[0]));
                }
            }
        }
        
        RegCloseKey(hKey);
    }
}

#endif