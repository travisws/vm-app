import SwiftUI

struct ContentView: View {
    @State private var vmStatus: String = "Unknown"
    @State private var isLoading: Bool = false
    @State private var serverURL: String = ""
    @State private var isFirstLaunch: Bool = true
    @State private var toastMessage: String = ""
    @State private var showToast: Bool = false
    @State private var selectedVM: String = ""
    @State private var vmList: [String] = []
    @State private var isAnimating: Bool = false
    @Environment(\.scenePhase) var scenePhase

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)

            VStack {
                if isFirstLaunch {
                    Text("Enter Server IP or Hostname")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()

                    TextField("e.g., http://192.168.1.10:8080", text: $serverURL)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(10)
                        .padding()

                    Button(action: saveServerURL) {
                        Text("Save")
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .padding()
                } else {
                    Picker("Select VM", selection: $selectedVM) {
                        ForEach(vmList, id: \.self) { vm in
                            Text(vm)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .onChange(of: selectedVM, perform: { _ in getStatus() })
                    .padding()

                    Text("Status: \(vmStatus)")
                        .foregroundColor(.white)
                        .padding()

                    Button(action: getStatus) {
                        Text("Get Status")
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .padding()

                    ZStack {
                        if isAnimating {
                            Circle()
                                .trim(from: 0, to: 0.8)
                                .stroke(Color.green, lineWidth: 8)
                                .frame(width: 50, height: 50)
                                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                                .animation(Animation.linear(duration: 1).repeatForever(autoreverses: false), value: isAnimating)
                        }

                        Button(action: {
                            isAnimating = true
                            startWithSnapshot()
                        }) {
                            Text("Start with Snapshot")
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.green)
                                .cornerRadius(10)
                        }
                        .padding()
                    }

                    Button(action: startWithoutSnapshot) {
                        Text("Start Without Snapshot")
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.purple)
                            .cornerRadius(10)
                    }
                    .padding()

                    Button(action: stop) {
                        Text("Stop")
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.orange)
                            .cornerRadius(10)
                    }
                    .padding()

                    Button(action: forceStop) {
                        Text("Force Stop")
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red)
                            .cornerRadius(10)
                    }
                    .padding()

                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .padding()
                    }
                }
            }
            .padding()

            if showToast {
                VStack {
                    Spacer()
                    Text(toastMessage)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(10)
                        .padding(.bottom, 50)
                        .transition(.opacity)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                                withAnimation {
                                    showToast = false
                                }
                            }
                        }
                }
            }
        }
        .onAppear {
            if !isFirstLaunch {
                loadVMList()
                getStatus()
            }
        }
        .onChange(of: scenePhase, perform: { newPhase in if newPhase == .active && !isFirstLaunch { getStatus() } })
    }

    func loadVMList() {
        guard let url = URL(string: "\(serverURL)/list-vms") else {
            showToastMessage("Invalid server URL")
            return
        }

        isLoading = true
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false

                if let error = error {
                    showToastMessage("Network error: \(error.localizedDescription)")
                    return
                }

                guard let data = data, let vmNames = try? JSONDecoder().decode([String].self, from: data) else {
                    showToastMessage("Failed to fetch VM list")
                    return
                }

                vmList = vmNames
                selectedVM = vmList.first ?? ""
            }
        }.resume()
    }

    func saveServerURL() {
        guard !serverURL.isEmpty else {
            showToastMessage("Server URL cannot be empty")
            return
        }

        UserDefaults.standard.set(serverURL, forKey: "serverURL")
        isFirstLaunch = false
        loadVMList()
    }

    func getStatus() {
        guard !selectedVM.isEmpty else {
            showToastMessage("No VM selected")
            return
        }

        guard let url = URL(string: "\(serverURL)/status?vm=\(selectedVM)") else {
            showToastMessage("Invalid server URL")
            return
        }

        isLoading = true
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false

                if let error = error {
                    showToastMessage("Network error: \(error.localizedDescription)")
                    return
                }

                guard let data = data, let statusResponse = try? JSONDecoder().decode([String: String].self, from: data), let status = statusResponse["status"] else {
                    showToastMessage("Failed to fetch VM status")
                    return
                }

                vmStatus = status
            }
        }.resume()
    }

    func startWithSnapshot() {
        sendPostRequest(endpoint: "/start?vm=\(selectedVM)", successMessage: "VM started with snapshot")
        isAnimating = false
    }

    func startWithoutSnapshot() {
        sendPostRequest(endpoint: "/start-no-snapshot?vm=\(selectedVM)", successMessage: "VM started without snapshot")
    }

    func stop() {
        sendPostRequest(endpoint: "/stop?vm=\(selectedVM)", successMessage: "VM stopped")
    }

    func forceStop() {
        sendPostRequest(endpoint: "/force-stop?vm=\(selectedVM)", successMessage: "VM force stopped")
    }

    func sendPostRequest(endpoint: String, successMessage: String) {
        guard let url = URL(string: "\(serverURL)\(endpoint)") else {
            showToastMessage("Invalid server URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        isLoading = true
        URLSession.shared.dataTask(with: request) { _, _, error in
            DispatchQueue.main.async {
                isLoading = false
                isAnimating = false

                if let error = error {
                    showToastMessage("Network error: \(error.localizedDescription)")
                    return
                }

                showToastMessage(successMessage)
                getStatus()
            }
        }.resume()
    }

    func showToastMessage(_ message: String) {
        toastMessage = message
        showToast = true
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
