import SwiftUI
import AVFoundation

@main
struct JournalApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                Splash()
            // شاشة البداية
                    .preferredColorScheme(.dark)
            }
        }
    }
}

// MARK: - Splash Screen (مطابقة للتصميم)
struct Splash: View {
    @State private var showIntro = false
    @State private var animate = false

    var body: some View {
        ZStack {
            if showIntro {
                Intro() // بعد 3 ثواني يفتح شاشة اليومية
            } else {
                // الخلفية الغامقة المتدرجة
                LinearGradient(
                    colors: [
                        Color(red: 0.03, green: 0.03, blue: 0.05),
                        Color(red: 0.09, green: 0.09, blue: 0.11)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 14) {
                    Spacer()

                    // شعار التطبيق (دفتر بنفسجي)
                    Image("SplashIcon") // أضفها إلى Assets باسم SplashIcon
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .scaleEffect(animate ? 1.0 : 0.85)
                        .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 5)

                    // اسم التطبيق
                    Text("Journali")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.top, 8)

                    // الوصف
                    Text("Your thoughts, your story")
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .padding(.top, 2)

                    Spacer()
                }
                .onAppear {
                    // حركة دخول ناعمة
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.65)) {
                        animate = true
                    }

                    // انتقال تلقائي بعد 3 ثواني
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            showIntro = true
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }
}

// MARK: - Intro Screen
struct Intro: View {
    @AppStorage("notes.v1") private var rawNotes: Data = Data()
    @AppStorage("sortMode") private var sortMode = 1

    @State private var items: [Item] = []
    @State private var search = ""
    @State private var editing: Item? = nil
    @State private var itemToDelete: Item? = nil
    @State private var showDeleteAlert = false
    @State private var isRecording = false

    private let accent = Color(red: 212/255, green: 200/255, blue: 255/255)
    private var recorder = AudioRecorder()

    private var displayed: [Item] {
        var arr = items
        if !search.isEmpty {
            arr = arr.filter {
                $0.title.localizedCaseInsensitiveContains(search) ||
                $0.content.localizedCaseInsensitiveContains(search)
            }
        }
        if sortMode == 0 {
            arr.sort { ($0.isBookmarked ? 0:1, $0.date) < ($1.isBookmarked ? 0:1, $1.date) }
        } else {
            arr.sort { $0.date > $1.date }
        }
        return arr
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: Header
            HStack(alignment: .firstTextBaseline) {
                Text("Journal")
                    .font(.system(size: 34, weight: .bold))

                Spacer()

                HStack(spacing: 18) {
                    Menu {
                        Picker("Sort", selection: $sortMode) {
                            Text("Sort by Bookmark").tag(0)
                            Text("Sort by Entry Date").tag(1)
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .menuIndicator(.hidden)

                    Button { editing = Item(title: "", content: "") } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(.ultraThinMaterial, in: Capsule())
                .tint(.primary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            // MARK: Empty / List
            if items.isEmpty && search.isEmpty {
                VStack(spacing: 0) {
                    Image("Splashpage2")
                        .resizable().scaledToFit()
                        .frame(width: 150, height: 150)
                    Text("Begin Your Journal")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(accent)
                        .padding(.top, 20)
                    Text("Craft your personal diary, tap the\nplus icon to begin")
                        .font(.system(size: 18, weight: .light))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(displayed) { it in
                        Card(
                            it: it,
                            accent: accent,
                            onBookmark: { toggleBookmark(id: it.id) },
                            onOpen: { editing = it },
                            onDelete: {
                                itemToDelete = it
                                showDeleteAlert = true
                            }
                        )
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(.init(top: 8, leading: 20, bottom: 8, trailing: 20))
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }

            // MARK: Search Bar + Mic
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").font(.system(size: 16))
                TextField("Search", text: $search)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)

                Button {
                    if isRecording {
                        recorder.stop()
                        isRecording = false
                        if let url = recorder.fileURL {
                            upsert(Item(title: "Voice Note", content: "", audioURL: url))
                        }
                    } else {
                        do { try recorder.start(); isRecording = true }
                        catch { print("Recording error:", error) }
                    }
                } label: {
                    Image(systemName: isRecording ? "stop.circle.fill" : "mic.fill")
                        .font(.system(size: 18))
                        .foregroundColor(isRecording ? .red : .primary)
                }
            }
            .foregroundColor(.primary.opacity(0.9))
            .frame(height: 44)
            .padding(.horizontal, 14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
        }
        .onAppear(perform: load)
        .fullScreenCover(item: $editing) { it in
            Editor(it: it, accent: accent) { saved in
                upsert(saved)
                editing = nil
            } onCancel: { editing = nil }
            .ignoresSafeArea(.keyboard)
        }
        .alert("Delete Journal?",
               isPresented: $showDeleteAlert,
               presenting: itemToDelete) { it in
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { delete(it) }
        } message: { _ in
            Text("Are you sure you want to delete this journal?")
        }
    }

    // MARK: Data Ops
    private func load() {
        guard !rawNotes.isEmpty,
              let arr = try? JSONDecoder().decode([Item].self, from: rawNotes) else { return }
        items = arr
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) { rawNotes = data }
    }

    private func upsert(_ it: Item) {
        if let i = items.firstIndex(where: { $0.id == it.id }) {
            items[i] = it
        } else {
            items.insert(it, at: 0)
        }
        save()
    }

    private func delete(_ it: Item) {
        items.removeAll { $0.id == it.id }
        save()
    }

    private func toggleBookmark(id: UUID) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].isBookmarked.toggle()
        save()
    }
}

// MARK: - Model
private struct Item: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var content: String
    var date: Date
    var isBookmarked: Bool
    var audioURL: URL?

    init(id: UUID = UUID(),
         title: String,
         content: String,
         date: Date = .now,
         isBookmarked: Bool = false,
         audioURL: URL? = nil) {
        self.id = id
        self.title = title
        self.content = content
        self.date = date
        self.isBookmarked = isBookmarked
        self.audioURL = audioURL
    }
}

// MARK: - Card
private struct Card: View {
    let it: Item
    let accent: Color
    var onBookmark: () -> Void
    var onOpen: () -> Void
    var onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                Text(it.title).font(.system(size: 22, weight: .bold))
                Text(it.date, style: .date)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                if !it.content.isEmpty {
                    Text(it.content)
                        .font(.system(size: 15))
                        .lineLimit(3)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 130, alignment: .leading)
            .padding(18)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26))
            .contentShape(RoundedRectangle(cornerRadius: 26))
            .onTapGesture { onOpen() }
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) { onDelete() } label: {
                    Label("Delete", systemImage: "trash")
                }
            }

            Button(action: onBookmark) {
                Image(systemName: it.isBookmarked ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(it.isBookmarked ? accent : .primary.opacity(0.9))
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .padding(10)
        }
    }
}

// MARK: - Editor
private struct Editor: View {
    @State var it: Item
    let accent: Color
    var onSave: (Item) -> Void
    var onCancel: () -> Void

    @State private var showAlert = false
    @FocusState private var focusTitle: Bool
    @FocusState private var focusBody: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button { showAlert = true } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                }

                Spacer()

                Button {
                    it.title = it.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    onSave(it)
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(accent, in: Circle())
                }
                .disabled(it.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(it.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)

            TextField("Title", text: $it.title)
                .font(.system(size: 32, weight: .bold))
                .focused($focusTitle)
                .submitLabel(.next)
                .onSubmit { focusBody = true }

            Text(it.date, style: .date)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.secondary)

            TextEditor(text: $it.content)
                .font(.system(size: 17))
                .frame(maxHeight: .infinity)
                .focused($focusBody)
        }
        .padding(.horizontal, 20)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { focusTitle = true }
        }
        .alert("Are you sure you want to discard changes on this journal?",
               isPresented: $showAlert) {
            Button("Discard Changes", role: .destructive) { onCancel() }
            Button("Keep Editing", role: .cancel) { }
        }
        .ignoresSafeArea(.keyboard)
    }
}

// MARK: - Audio Recorder
private final class AudioRecorder {
    private var recorder: AVAudioRecorder?
    private(set) var fileURL: URL?

    func start() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)

        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("rec_\(UUID().uuidString.prefix(8)).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let rec = try AVAudioRecorder(url: url, settings: settings)
        rec.record()
        recorder = rec
        fileURL = url
    }

    func stop() {
        recorder?.stop()
        recorder = nil
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}
