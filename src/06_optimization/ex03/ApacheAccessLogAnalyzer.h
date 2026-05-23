#include "HostCounter.h"

#include <string>
#include <vector>
#include <fstream>

class ApacheAccessLogAnalyzer
{
    public:
        ApacheAccessLogAnalyzer(const std::string filename);

        void openFile();
        void closeFile();
        void processFile();

    private:
        std::string     myFilename;
        std::ifstream   myInFile;
        HostCounter     myHostCounter;
};
