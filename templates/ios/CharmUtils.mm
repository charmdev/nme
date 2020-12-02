#include <Utils.h>

extern "C" void nme_app_set_active(bool inActive);

namespace nme
{
    int SetActivateApp()
    {
        nme_app_set_active(true);
        return 1;
    }

    int SetDeactivateApp()
    {
        nme_app_set_active(false);
        return 0;
    }
}
