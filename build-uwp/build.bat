call z:\root\build\env-%1.bat

%SCONS% platform=uwp %OPTIONS% tools=no target=%2 LINK="\"C:\Program Files (x86)\Microsoft Visual Studio\2017\BuildTools\VC\Tools\MSVC\14.16.27023\bin\HostX64\%1\link.exe\""
