#include <iostream>

extern "C" {
    void foo(void);
}

int main(int argc, char * argv[])
{
    foo();
    std::cout << "main" << std::endl;
    return 0;
}
