#include "daq_native_bridge.h"

#include <flutter/event_channel.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/standard_method_codec.h>

#include <algorithm>
#include <cmath>
#include <cctype>
#include <cstring>
#include <functional>
#include <iomanip>
#include <sstream>
#include <string>
#include <utility>
#include <vector>

#include <windows.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

#define DAQMX_ERR_CHK(function_call) \
  if (DAQmxFailed(error = (function_call))) goto Error; else

namespace {

constexpr char kMethodChannelName[] = "mine_alert/daq_bridge_method";
constexpr char kEventChannelName[] = "mine_alert/daq_bridge_events";

struct DaqmxApi {
  using CreateTaskFn = decltype(&DAQmxCreateTask);
  using StartTaskFn = decltype(&DAQmxStartTask);
  using StopTaskFn = decltype(&DAQmxStopTask);
  using ClearTaskFn = decltype(&DAQmxClearTask);
  using CreateAIVoltageChanFn = decltype(&DAQmxCreateAIVoltageChan);
  using CreateAIAccelChanFn = decltype(&DAQmxCreateAIAccelChan);
  using CfgSampClkTimingFn = decltype(&DAQmxCfgSampClkTiming);
  using ReadAnalogF64Fn = decltype(&DAQmxReadAnalogF64);
  using GetExtendedErrorInfoFn = decltype(&DAQmxGetExtendedErrorInfo);
  using GetDevSerialNumFn = decltype(&DAQmxGetDevSerialNum);
  using GetSysDevNamesFn = decltype(&DAQmxGetSysDevNames);
  using GetTaskNumChansFn = decltype(&DAQmxGetTaskNumChans);

  bool Load(std::string* error) {
    if (module != nullptr) {
      return true;
    }

    module = ::LoadLibraryW(L"nicaiu.dll");
    if (module == nullptr) {
      *error =
          "Khong the nap nicaiu.dll. Can cai NI-DAQmx runtime x64 tren may Windows.";
      return false;
    }

    return Resolve("DAQmxCreateTask", &create_task, error) &&
           Resolve("DAQmxStartTask", &start_task, error) &&
           Resolve("DAQmxStopTask", &stop_task, error) &&
           Resolve("DAQmxClearTask", &clear_task, error) &&
           Resolve("DAQmxCreateAIVoltageChan", &create_ai_voltage_chan,
                   error) &&
           Resolve("DAQmxCreateAIAccelChan", &create_ai_accel_chan, error) &&
           Resolve("DAQmxCfgSampClkTiming", &cfg_samp_clk_timing, error) &&
           Resolve("DAQmxReadAnalogF64", &read_analog_f64, error) &&
           Resolve("DAQmxGetExtendedErrorInfo", &get_extended_error_info,
                   error) &&
           Resolve("DAQmxGetDevSerialNum", &get_dev_serial_num, error) &&
           Resolve("DAQmxGetSysDevNames", &get_sys_dev_names, error) &&
           Resolve("DAQmxGetTaskNumChans", &get_task_num_chans, error);
  }

  bool is_loaded() const { return module != nullptr; }

  HMODULE module = nullptr;
  CreateTaskFn create_task = nullptr;
  StartTaskFn start_task = nullptr;
  StopTaskFn stop_task = nullptr;
  ClearTaskFn clear_task = nullptr;
  CreateAIVoltageChanFn create_ai_voltage_chan = nullptr;
  CreateAIAccelChanFn create_ai_accel_chan = nullptr;
  CfgSampClkTimingFn cfg_samp_clk_timing = nullptr;
  ReadAnalogF64Fn read_analog_f64 = nullptr;
  GetExtendedErrorInfoFn get_extended_error_info = nullptr;
  GetDevSerialNumFn get_dev_serial_num = nullptr;
  GetSysDevNamesFn get_sys_dev_names = nullptr;
  GetTaskNumChansFn get_task_num_chans = nullptr;

 private:
  template <typename T>
  bool Resolve(const char* name, T* target, std::string* error) {
    auto* proc = ::GetProcAddress(module, name);
    if (proc == nullptr) {
      *error = std::string("Khong tim thay ham NI-DAQmx: ") + name;
      return false;
    }
    *target = reinterpret_cast<T>(proc);
    return true;
  }
};

DaqmxApi& GetDaqmxApi() {
  static DaqmxApi api;
  return api;
}

std::string TrimCopy(const char* text) {
  const char* begin = text;
  while (*begin == ' ' || *begin == '\t') {
    ++begin;
  }

  const char* end = begin + std::strlen(begin);
  while (end > begin && (end[-1] == ' ' || end[-1] == '\t')) {
    --end;
  }

  return std::string(begin, static_cast<size_t>(end - begin));
}

bool IsDeviceReachable(const char* device) {
  auto& api = GetDaqmxApi();
  uInt32 serial = 0;
  return !DAQmxFailed(api.get_dev_serial_num(device, &serial));
}

void ScanDevices(const std::function<void(const std::string&)>& emit) {
  auto& api = GetDaqmxApi();
  char dev_names[4096] = {'\0'};
  int32 status = api.get_sys_dev_names(dev_names, sizeof(dev_names));

  if (DAQmxFailed(status) || std::strlen(dev_names) == 0) {
    emit("[CANH BAO] Khong tim thay thiet bi DAQmx nao.");
    return;
  }

  char list_copy[4096] = {'\0'};
  strncpy_s(list_copy, sizeof(list_copy), dev_names, _TRUNCATE);

  int found_count = 0;
  char* context = nullptr;
  char* token = strtok_s(list_copy, ",", &context);
  while (token != nullptr) {
    std::string dev = TrimCopy(token);
    if (IsDeviceReachable(dev.c_str())) {
      emit("[OK]      Thiet bi ket noi: " + dev);
      ++found_count;
    } else {
      emit("[OFFLINE] Thiet bi khong ket noi: " + dev);
    }
    token = strtok_s(nullptr, ",", &context);
  }

  if (found_count == 0) {
    emit("[CANH BAO] Khong co thiet bi nao dang ket noi.");
  }
}

bool ArgEquals(const std::string& arg, const char* short_form,
               const char* long_form) {
  return arg == short_form || arg == long_form;
}

std::string ToLowerCopy(const std::string& text) {
  std::string result = text;
  std::transform(result.begin(), result.end(), result.begin(),
                 [](unsigned char ch) {
                   return static_cast<char>(std::tolower(ch));
                 });
  return result;
}

bool TryParseAiMode(const std::string& text,
                    DaqNativeBridge::AiChannelMode* mode) {
  if (mode == nullptr) {
    return false;
  }

  const std::string value = ToLowerCopy(text);
  if (value == "voltage" || value == "volt") {
    *mode = DaqNativeBridge::AiChannelMode::kVoltage;
    return true;
  }
  if (value == "accel" || value == "acceleration") {
    *mode = DaqNativeBridge::AiChannelMode::kAcceleration;
    return true;
  }
  return false;
}

const char* AiModeName(DaqNativeBridge::AiChannelMode mode) {
  return mode == DaqNativeBridge::AiChannelMode::kAcceleration ? "accel"
                                                               : "voltage";
}

int32 CreateAiInputChannel(TaskHandle task_handle, const char* channel,
                           DaqNativeBridge::AiChannelMode mode,
                           float64 min_value, float64 max_value,
                           float64 accel_sensitivity_mv_per_g) {
  auto& api = GetDaqmxApi();
  if (mode == DaqNativeBridge::AiChannelMode::kAcceleration) {
    return api.create_ai_accel_chan(
        task_handle, channel, "", DAQmx_Val_Cfg_Default, min_value, max_value,
        DAQmx_Val_AccelUnit_g, accel_sensitivity_mv_per_g,
        DAQmx_Val_mVoltsPerG, DAQmx_Val_None, 0.0, nullptr);
  }

  return api.create_ai_voltage_chan(task_handle, channel, "",
                                    DAQmx_Val_Cfg_Default, min_value,
                                    max_value, DAQmx_Val_Volts, nullptr);
}

int NextPow2(int n) {
  int p = 1;
  while (p < n) {
    p <<= 1;
  }
  return p;
}

void ComputeFftMagnitudes(const double* input, int samples_read, int fft_n,
                          std::vector<double>* out) {
  std::vector<double> re(static_cast<size_t>(fft_n), 0.0);
  std::vector<double> im(static_cast<size_t>(fft_n), 0.0);

  double mean = 0.0;
  for (int i = 0; i < samples_read; ++i) {
    mean += input[i];
  }
  mean /= samples_read;

  for (int i = 0; i < samples_read; ++i) {
    const double hann = 0.5 *
                        (1.0 - std::cos(2.0 * M_PI * i /
                                         static_cast<double>(fft_n - 1)));
    re[static_cast<size_t>(i)] = (input[i] - mean) * hann;
  }

  for (int i = 1, j = 0; i < fft_n; ++i) {
    int bit = fft_n >> 1;
    for (; j & bit; bit >>= 1) {
      j ^= bit;
    }
    j ^= bit;
    if (i < j) {
      std::swap(re[static_cast<size_t>(i)], re[static_cast<size_t>(j)]);
      std::swap(im[static_cast<size_t>(i)], im[static_cast<size_t>(j)]);
    }
  }

  for (int len = 2; len <= fft_n; len <<= 1) {
    const double ang = -2.0 * M_PI / len;
    const double w_re = std::cos(ang);
    const double w_im = std::sin(ang);
    for (int i = 0; i < fft_n; i += len) {
      double cur_re = 1.0;
      double cur_im = 0.0;
      for (int k = 0; k < len / 2; ++k) {
        const size_t lo = static_cast<size_t>(i + k);
        const size_t hi = static_cast<size_t>(i + k + len / 2);
        const double u_re = re[lo];
        const double u_im = im[lo];
        const double v_re = re[hi] * cur_re - im[hi] * cur_im;
        const double v_im = re[hi] * cur_im + im[hi] * cur_re;
        re[lo] = u_re + v_re;
        im[lo] = u_im + v_im;
        re[hi] = u_re - v_re;
        im[hi] = u_im - v_im;
        const double n_re = cur_re * w_re - cur_im * w_im;
        cur_im = cur_re * w_im + cur_im * w_re;
        cur_re = n_re;
      }
    }
  }

  const int half = fft_n / 2;
  out->resize(static_cast<size_t>(half));
  for (int k = 0; k < half; ++k) {
    (*out)[static_cast<size_t>(k)] =
        std::sqrt(re[k] * re[k] + im[k] * im[k]) / half;
  }
}

}  // namespace

DaqNativeBridge::DaqNativeBridge(flutter::BinaryMessenger* messenger) {
  RegisterChannels(messenger);
}

DaqNativeBridge::~DaqNativeBridge() {
  Stop();
}

void DaqNativeBridge::RegisterChannels(flutter::BinaryMessenger* messenger) {
  method_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, kMethodChannelName,
      &flutter::StandardMethodCodec::GetInstance());
  method_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        HandleMethodCall(call, std::move(result));
      });

  event_channel_ = std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
      messenger, kEventChannelName,
      &flutter::StandardMethodCodec::GetInstance());
  event_channel_->SetStreamHandler(
      std::make_unique<flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
          [this](const flutter::EncodableValue* /*arguments*/,
                 std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&&
                     events) {
            std::lock_guard<std::mutex> lock(event_sink_mutex_);
            event_sink_ = std::move(events);
            return std::unique_ptr<
                flutter::StreamHandlerError<flutter::EncodableValue>>();
          },
          [this](const flutter::EncodableValue* /*arguments*/) {
            std::lock_guard<std::mutex> lock(event_sink_mutex_);
            event_sink_.reset();
            return std::unique_ptr<
                flutter::StreamHandlerError<flutter::EncodableValue>>();
          }));
}

void DaqNativeBridge::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string& method = method_call.method_name();
  if (method == "startBridge") {
    const auto* arguments = std::get_if<flutter::EncodableMap>(
        method_call.arguments());
    std::string error;
    if (!StartBridge(arguments, &error)) {
      result->Error("start_failed", error);
      return;
    }
    result->Success(flutter::EncodableValue(true));
    return;
  }

  if (method == "stopBridge") {
    Stop();
    result->Success(flutter::EncodableValue(true));
    return;
  }

  if (method == "isBridgeRunning") {
    result->Success(flutter::EncodableValue(running_.load()));
    return;
  }

  result->NotImplemented();
}

bool DaqNativeBridge::StartBridge(const flutter::EncodableMap* arguments,
                                  std::string* error) {
  auto& api = GetDaqmxApi();
  if (!api.Load(error)) {
    return false;
  }

  if (running_.load()) {
    *error = "Bridge is already running.";
    return false;
  }

  StreamConfig config;
  if (!ParseStartArguments(arguments, &config, error)) {
    return false;
  }

  Stop();
  stop_requested_.store(false);
  running_.store(true);
  worker_thread_ = std::thread([this, config]() { RunStreamWorker(config); });
  EmitLine("BRIDGE_STARTED,in-process");
  return true;
}

bool DaqNativeBridge::ParseStartArguments(const flutter::EncodableMap* arguments,
                                          StreamConfig* config,
                                          std::string* error) const {
  if (config == nullptr) {
    *error = "Bridge configuration is missing.";
    return false;
  }

  std::vector<std::string> args;
  if (arguments != nullptr) {
    const auto args_it = arguments->find(flutter::EncodableValue("args"));
    if (args_it != arguments->end()) {
      const auto* list = std::get_if<flutter::EncodableList>(&args_it->second);
      if (list == nullptr) {
        *error = "Bridge args must be a list of strings.";
        return false;
      }
      for (const auto& value : *list) {
        const auto* text = std::get_if<std::string>(&value);
        if (text == nullptr) {
          *error = "Bridge args contains a non-string value.";
          return false;
        }
        args.push_back(*text);
      }
    }
  }

  bool stream_mode = false;
  for (size_t i = 0; i < args.size(); ++i) {
    const std::string& arg = args[i];
    if (ArgEquals(arg, "-s", "--stream")) {
      stream_mode = true;
      continue;
    }
    if (ArgEquals(arg, "-r", "--rate") && i + 1 < args.size()) {
      config->sample_rate_hz = std::atof(args[++i].c_str());
      continue;
    }
    if (ArgEquals(arg, "-n", "--samples") && i + 1 < args.size()) {
      config->samples_per_read = static_cast<int32>(
          std::atoi(args[++i].c_str()));
      continue;
    }
    if (arg == "--min" && i + 1 < args.size()) {
      config->min_voltage = std::atof(args[++i].c_str());
      continue;
    }
    if (arg == "--max" && i + 1 < args.size()) {
      config->max_voltage = std::atof(args[++i].c_str());
      continue;
    }
    if (arg == "--ai-mode" && i + 1 < args.size()) {
      if (!TryParseAiMode(args[++i], &config->channel_mode)) {
        *error = "Tham so --ai-mode chi nhan: voltage | accel";
        return false;
      }
      continue;
    }
    if (arg == "--accel-sens" && i + 1 < args.size()) {
      config->accel_sensitivity_mv_per_g = std::atof(args[++i].c_str());
      continue;
    }
    if (arg == "--fft-bins" && i + 1 < args.size()) {
      config->fft_bins_out = std::atoi(args[++i].c_str());
      continue;
    }
    if (!arg.empty() && arg[0] == '-') {
      continue;
    }
    config->channel = arg;
  }

  if (!stream_mode) {
    *error = "Native bridge chi ho tro che do --stream.";
    return false;
  }
  if (config->sample_rate_hz <= 0.0) {
    *error = "Tham so --rate khong hop le.";
    return false;
  }
  if (config->samples_per_read <= 0) {
    *error = "Tham so --samples khong hop le.";
    return false;
  }
  if (config->min_voltage >= config->max_voltage) {
    *error = "Tham so --min/--max khong hop le.";
    return false;
  }
  if (config->accel_sensitivity_mv_per_g <= 0.0) {
    *error = "Tham so --accel-sens khong hop le.";
    return false;
  }

  return true;
}

void DaqNativeBridge::RunStreamWorker(StreamConfig config) {
  ScanDevices([this](const std::string& line) { EmitLine(line); });
  const int exit_code = RunStreamRead(config);
  running_.store(false);
  EmitBridgeStopped(exit_code);
}

int DaqNativeBridge::RunStreamRead(const StreamConfig& config) {
  auto& api = GetDaqmxApi();
  int32 error = 0;
  TaskHandle task_handle = 0;
  char err_buff[2048] = {'\0'};
  uInt32 channel_count = 0;
  std::vector<float64> samples;

  DAQMX_ERR_CHK(api.create_task("", &task_handle));
  {
    std::lock_guard<std::mutex> lock(task_mutex_);
    active_task_ = task_handle;
  }
  DAQMX_ERR_CHK(CreateAiInputChannel(task_handle, config.channel.c_str(),
                                     config.channel_mode, config.min_voltage,
                                     config.max_voltage,
                                     config.accel_sensitivity_mv_per_g));

  DAQMX_ERR_CHK(api.get_task_num_chans(task_handle, &channel_count));
  if (channel_count == 0) {
    EmitLine("ERROR,Khong co kenh hop le de stream.");
    error = -1;
    goto Error;
  }
  samples.resize(static_cast<size_t>(config.samples_per_read) * channel_count,
                 0.0);

  DAQMX_ERR_CHK(api.cfg_samp_clk_timing(
      task_handle, "", config.sample_rate_hz, DAQmx_Val_Rising,
      DAQmx_Val_ContSamps,
      static_cast<uInt64>(config.samples_per_read * 10)));

  DAQMX_ERR_CHK(api.start_task(task_handle));

  {
    std::ostringstream line;
    line << "STREAM_STARTED," << config.channel << "," << config.sample_rate_hz
         << "," << config.samples_per_read << "," << channel_count << ","
         << AiModeName(config.channel_mode);
    EmitLine(line.str());
  }

  while (!stop_requested_.load()) {
    int32 samples_read = 0;
    DAQMX_ERR_CHK(api.read_analog_f64(
        task_handle, config.samples_per_read, 10.0, DAQmx_Val_GroupByScanNumber,
        samples.data(), static_cast<uInt32>(samples.size()), &samples_read,
        nullptr));

    if (samples_read <= 0) {
      continue;
    }

    std::vector<double> rms_by_channel(static_cast<size_t>(channel_count), 0.0);
    for (uInt32 ch = 0; ch < channel_count; ++ch) {
      double sq_sum = 0.0;
      for (int32 i = 0; i < samples_read; ++i) {
        const size_t sample_index = static_cast<size_t>(i) * channel_count + ch;
        const double value = samples[sample_index];
        sq_sum += value * value;
      }
      rms_by_channel[static_cast<size_t>(ch)] =
          std::sqrt(sq_sum / static_cast<double>(samples_read));
    }

    {
      std::ostringstream line;
      line << "DATA_MULTI," << config.sample_rate_hz << "," << samples_read
           << "," << channel_count;
      for (uInt32 ch = 0; ch < channel_count; ++ch) {
        line << "," << rms_by_channel[static_cast<size_t>(ch)];
      }
      EmitLine(line.str());
    }

    {
      const int fft_n = NextPow2(static_cast<int>(samples_read));
      const int half_n = fft_n / 2;
      const int bins_out =
          (config.fft_bins_out > 0 && config.fft_bins_out < half_n)
              ? config.fft_bins_out
              : half_n;

      std::vector<double> ch_input(static_cast<size_t>(samples_read));
      std::vector<double> mags;
      std::ostringstream line;
      line << "FFT_MULTI," << static_cast<int>(config.sample_rate_hz) << ","
           << samples_read << "," << channel_count << "," << bins_out;
      line << std::fixed << std::setprecision(6);

      for (uInt32 ch = 0; ch < channel_count; ++ch) {
        for (int32 i = 0; i < samples_read; ++i) {
          ch_input[static_cast<size_t>(i)] =
              samples[static_cast<size_t>(i) * channel_count + ch];
        }
        ComputeFftMagnitudes(ch_input.data(), samples_read, fft_n, &mags);
        for (int b = 0; b < bins_out; ++b) {
          line << "," << mags[static_cast<size_t>(b)];
        }
      }
      EmitLine(line.str());
    }

    {
      constexpr int kDecimStep = 5;
      std::ostringstream line;
      line << "WAVE_MULTI," << static_cast<int>(config.sample_rate_hz) << ","
           << samples_read << "," << channel_count << "," << kDecimStep;
      line << std::fixed << std::setprecision(6);
      for (uInt32 ch = 0; ch < channel_count; ++ch) {
        for (int32 i = 0; i < samples_read; i += kDecimStep) {
          line << ","
               << samples[static_cast<size_t>(i) * channel_count + ch];
        }
      }
      EmitLine(line.str());
    }
  }

Error:
  if (task_handle != 0) {
    api.stop_task(task_handle);
    api.clear_task(task_handle);
  }
  {
    std::lock_guard<std::mutex> lock(task_mutex_);
    active_task_ = 0;
  }

  if (DAQmxFailed(error) && !stop_requested_.load()) {
    api.get_extended_error_info(err_buff, sizeof(err_buff));
    EmitLine(std::string("ERROR,") + err_buff);
    return 1;
  }

  return 0;
}

void DaqNativeBridge::Stop() {
  stop_requested_.store(true);
  {
    std::lock_guard<std::mutex> lock(task_mutex_);
    auto& api = GetDaqmxApi();
    if (active_task_ != 0 && api.is_loaded()) {
      api.stop_task(active_task_);
    }
  }

  if (worker_thread_.joinable()) {
    worker_thread_.join();
  }
  running_.store(false);
}

void DaqNativeBridge::EmitLine(const std::string& line) {
  std::lock_guard<std::mutex> lock(event_sink_mutex_);
  if (event_sink_ != nullptr) {
    event_sink_->Success(flutter::EncodableValue(line));
  }
}

void DaqNativeBridge::EmitBridgeStopped(int exit_code) {
  std::ostringstream line;
  line << "BRIDGE_STOPPED," << exit_code;
  EmitLine(line.str());
}