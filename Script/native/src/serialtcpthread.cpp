#include "serialtcpthread.h"

using namespace godot;

extern "C" {
#include "dyad.h"
}

SerialTcpThread::SerialTcpThread() {
}

void SerialTcpThread::_register_methods() {
    register_method("start_tcp", &SerialTcpThread::start_tcp);
    register_method("stop_tcp", &SerialTcpThread::stop_tcp);
}

static bool workerRunning = false;
// static pthread_t tcpWorker;

static void *tcpThread(void * /*data*/) {
    printf("tcpThread start!!\n");
    dyad_init();
    dyad_setTickInterval(0.2);
    dyad_setUpdateTimeout(0.5);

    while (workerRunning) {
        dyad_update();
    }

    dyad_shutdown();
    printf("tcpThread end!!\n");
    return nullptr;
}

void SerialTcpThread::start_tcp() {
    workerRunning = true;
    dyad_init();
    dyad_setTickInterval(0.2);
    dyad_setUpdateTimeout(0.0);
    /*
    int ret = pthread_create(&tcpWorker, nullptr, tcpThread, nullptr);
    if (ret != 0) {
        printf("Create tcpWorker error!\n");
        exit(1);
    }
    */
}

void SerialTcpThread::stop_tcp() {
    workerRunning = false;
    dyad_shutdown();
    // pthread_join(tcpWorker, nullptr);
}
