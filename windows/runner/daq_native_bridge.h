#ifndef RUNNER_DAQ_NATIVE_BRIDGE_H_
#define RUNNER_DAQ_NATIVE_BRIDGE_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/method_channel.h>

#include <NIDAQmx.h>

#include <atomic>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

class DaqNativeBridge {
 public:
  enum class AiChannelMode {
    kVoltage,
    kAcceleration,
  };

  explicit DaqNativeBridge(flutter::BinaryMessenger* messenger);
  ~DaqNativeBridge();

  DaqNativeBridge(const DaqNativeBridge&) = delete;
  DaqNativeBridge& operator=(const DaqNativeBridge&) = delete;

  void Stop();

 private:
  struct StreamConfig {
    std::string channel = "cDAQ9181-1E439C1Mod1/ai0:15";
    double sample_rate_hz = 10000.0;
    int32 samples_per_read = 1000;
    double min_voltage = -10.0;
    double max_voltage = 10.0;
    AiChannelMode channel_mode = AiChannelMode::kVoltage;
    double accel_sensitivity_mv_per_g = 100.0;
    int fft_bins_out = 0;
  };

  void RegisterChannels(flutter::BinaryMessenger* messenger);
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  bool StartBridge(const flutter::EncodableMap* arguments, std::string* error);
  bool ParseStartArguments(const flutter::EncodableMap* arguments,
                           StreamConfig* config, std::string* error) const;
  void RunStreamWorker(StreamConfig config);
  int RunStreamRead(const StreamConfig& config);
  void EmitLine(const std::string& line);
  void EmitBridgeStopped(int exit_code);

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      method_channel_;
  std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>> event_channel_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;

  std::thread worker_thread_;
  std::atomic<bool> stop_requested_{false};
  std::atomic<bool> running_{false};
  mutable std::mutex event_sink_mutex_;
  mutable std::mutex task_mutex_;
  TaskHandle active_task_ = 0;
};

#endif  // RUNNER_DAQ_NATIVE_BRIDGE_H_