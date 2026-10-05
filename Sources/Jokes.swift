import Foundation

/// The lazy cat's material: fresh jokes from Reddit when it's reachable
/// (see `RedditJokes`), and a bundled list of cat jokes and dad jokes for
/// when it isn't. Your own go in ~/Library/Application Support/
/// Monsieur Pierre/jokes.txt, one per line ("\n" in a line starts a new
/// line in the bubble), and are always in the mix.
enum Jokes {
    static let builtIn: [String] = [
        // Cat jokes
        "Why was the cat sitting on the computer?\nTo keep an eye on the mouse.",
        "What do you call a pile of kittens?\nA meowtain.",
        "Why don't cats play poker in the jungle?\nToo many cheetahs.",
        "What's a cat's favourite colour?\nPurrple.",
        "How do cats end a fight?\nThey hiss and make up.",
        "What do cats eat for breakfast?\nMice Krispies.",
        "What's a cat's favourite dessert?\nChocolate mouse.",
        "Why did the cat join the Red Cross?\nShe wanted to be a first-aid kit.",
        "What do you call a cat that gets anything it wants?\nPurrsuasive.",
        "What's a cat's favourite magazine?\nGood Mousekeeping.",
        "Why are cats bad storytellers?\nThey only have one tail.",
        "What do you call a cat that loves to bowl?\nAn alley cat.",
        "What's a cat's favourite button on the remote?\nPaws.",
        "Why did the cat sit next to the computer all day?\nIt was waiting for a byte.",
        "How does a cat sing scales?\nDo-re-mew.",
        "What do you call a cat wearing shoes?\nPuss in boots. Obviously.",
        "What did the cat say when he lost all his money?\n\"I'm paw.\"",
        "Why do cats always get their way?\nThey are very purr-suasive.",
        "What's a cat's favourite car?\nA Catillac.",
        "Where do cats go when they lose their tails?\nThe retail store.",
        "What do you call a cat that does magic?\nA magicat.",
        "Why did the cat wear a dress?\nShe was feline fine.",
        "What is a cat's way of keeping law and order?\nClaw enforcement.",
        "How do cats bake cakes?\nFrom scratch.",
        "Why was the cat afraid of the tree?\nIts bark.",
        "What does a cat call its human?\nStaff.",
        "What's a cat's favourite subject at school?\nHiss-tory.",
        "Why did the kitten get in trouble at school?\nIt was caught copycatting.",
        "What do you call a cat that eats lemons?\nA sourpuss.",
        "What do you call a cat who becomes a lawyer?\nAn a-paw-ney.",
        "Why don't cats like online shopping?\nThey prefer a cat-alogue.",
        "What did the cat say to the dog?\n\"Check meowt.\"",
        "How do you know your cat ate a duck?\nShe's down in the mouth.",
        "What do you call a cat in a station wagon?\nA car-pet.",
        "What's a cat's favourite TV show?\nThe evening mews.",
        "Why did the cat take up gardening?\nIt had a natural litter talent.",
        "What does a cat use to make coffee?\nA purr-colator.",
        "Why did the cat cross the road?\nIt was the chicken's day off.",
        "What's a cat's favourite instrument?\nThe purr-cussion.",
        "Why are cats good at video games?\nThey have nine lives.",
        "Why did the cat sleep under the car?\nHe wanted to wake up oily.",
        "What happened when the cat swallowed a ball of wool?\nShe had mittens.",
        "What's the unluckiest kind of cat?\nA catastrophe.",
        "What do you call a cat with eight legs that likes water?\nAn octopuss.",
        "How do cats greet each other?\n\"Hello, fur-iend.\"",
        "I'm not lazy.\nI'm in energy-saving mode.",
        "I've been napping for six hours.\nTime for a break.",
        "Monsieur Pierre's schedule:\nnap, snack, nap, judge you, nap.",
        "I could chase the mouse.\nOr the other cat could. He loves that.",
        "I'm not fat.\nI'm fluffy with ambition.",
        // Dad jokes
        "I'm reading a book about anti-gravity.\nIt's impossible to put down.",
        "Why don't skeletons fight each other?\nThey don't have the guts.",
        "What do you call fake spaghetti?\nAn impasta.",
        "Why did the scarecrow win an award?\nHe was outstanding in his field.",
        "I used to hate facial hair,\nbut then it grew on me.",
        "What do you call a fish with no eyes?\nA fsh.",
        "Why couldn't the bicycle stand up by itself?\nIt was two tired.",
        "I only know 25 letters of the alphabet.\nI don't know y.",
        "What did the ocean say to the beach?\nNothing, it just waved.",
        "Why do seagulls fly over the sea?\nBecause if they flew over the bay, they'd be bagels.",
        "How do you organise a space party?\nYou planet.",
        "What do you call a bear with no teeth?\nA gummy bear.",
        "I would tell you a joke about construction,\nbut I'm still working on it.",
        "Why did the coffee file a police report?\nIt got mugged.",
        "What do you call a factory that makes okay products?\nA satisfactory.",
        "Why don't eggs tell jokes?\nThey'd crack each other up.",
        "Did you hear about the claustrophobic astronaut?\nHe just needed a little space.",
        "What do you call a sleeping dinosaur?\nA dino-snore.",
        "Why did the math book look so sad?\nIt had too many problems.",
        "What do you call cheese that isn't yours?\nNacho cheese.",
        "I'm on a seafood diet.\nI see food and I eat it.",
        "What did the janitor say when he jumped out of the closet?\n\"Supplies!\"",
        "Why did the golfer bring two pairs of trousers?\nIn case he got a hole in one.",
        "How does a penguin build its house?\nIgloos it together.",
        "What do you call a pony with a cough?\nA little hoarse.",
        "Why can't you trust atoms?\nThey make up everything.",
        "What did one wall say to the other?\n\"I'll meet you at the corner.\"",
        "Why did the computer go to the doctor?\nIt had a virus.",
        "What's brown and sticky?\nA stick.",
        "Why don't programmers like nature?\nToo many bugs.",
        "I told my computer I needed a break.\nIt said: \"No problem, I'll go to sleep.\"",
        "How do you make a tissue dance?\nPut a little boogie in it.",
        "What do you call a dog that does magic tricks?\nA labracadabrador.",
        "Why was the broom late?\nIt over-swept.",
        "What did the grape do when it got stepped on?\nIt let out a little wine.",
        "What's orange and sounds like a parrot?\nA carrot.",
        "Why do cows wear bells?\nBecause their horns don't work.",
        "What did the zero say to the eight?\n\"Nice belt.\"",
        "Why are elevator jokes so good?\nThey work on so many levels.",
        "I got a job at a bakery because I kneaded dough.",
        "What do you call a belt made of watches?\nA waist of time.",
        "Why did the tomato blush?\nIt saw the salad dressing.",
        "How do you catch a squirrel?\nClimb a tree and act like a nut.",
        "Why did the picture go to jail?\nIt was framed.",
        "What kind of shoes do ninjas wear?\nSneakers.",
        "Why can't a nose be 12 inches long?\nThen it would be a foot.",
        "What do you call a fly without wings?\nA walk.",
        "Why did the cookie go to the hospital?\nIt felt crummy.",
        "Want to hear a joke about paper?\nNever mind, it's tearable.",
        "What do you call an alligator in a vest?\nAn investigator.",
    ]

    static var userFile: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory,
                                               in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support")
        return support.appendingPathComponent("Monsieur Pierre/jokes.txt")
    }

    /// Your own jokes, read fresh each time so edits show up without a
    /// restart. Blank lines and lines starting with # are skipped.
    static var userJokes: [String] {
        guard let text = try? String(contentsOf: userFile, encoding: .utf8) else { return [] }
        return text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
            .map { $0.replacingOccurrences(of: "\\n", with: "\n") }
    }

    /// Filled in by `RedditJokes`; empty when off, offline or not fetched yet.
    static var reddit: [String] = []

    private static var recent: [String] = []

    /// A random joke that hasn't been told in the last 30: Reddit's when
    /// there are any, else the built-in ones; plus your own either way.
    static func next() -> String {
        let pool = (reddit.isEmpty ? builtIn : reddit) + userJokes
        let fresh = pool.filter { !recent.contains($0) }
        let joke = (fresh.isEmpty ? pool : fresh).randomElement() ?? "…"
        recent.append(joke)
        if recent.count > 30 { recent.removeFirst() }
        return joke
    }
}

/// Fetches top posts from clean joke subreddits through Reddit's public JSON
/// listings, a few times a day. Only short text posts that aren't marked
/// NSFW or spoiler, aren't pinned and score well make it into the list.
/// Anything that goes wrong just leaves the built-in jokes in charge.
final class RedditJokes {
    var isEnabled = false {
        didSet {
            guard isEnabled != oldValue else { return }
            isEnabled ? start() : stop()
        }
    }

    private static let subreddits = ["dadjokes", "cleanjokes", "catpuns"]
    private static let refresh: TimeInterval = 6 * 60 * 60
    private static let minScore = 50
    private static let maxLength = 160
    private static let blocked = ["http", "[removed]", "[deleted]", "edit:", "r/", "u/", "nsfw"]

    private var timer: Timer?
    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        // Reddit asks API clients for a descriptive User-Agent.
        config.httpAdditionalHeaders = [
            "User-Agent": "macos:com.lolesterrr.monsieurpierre:1.0 (desktop cat)",
        ]
        return URLSession(configuration: config)
    }()

    private func start() {
        fetch()
        let timer = Timer(timeInterval: Self.refresh, repeats: true) { [weak self] _ in
            self?.fetch()
        }
        timer.tolerance = 600
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
        Jokes.reddit = []
    }

    private func fetch() {
        let group = DispatchGroup()
        var collected: [String] = []
        let lock = NSLock()
        for name in Self.subreddits {
            guard let url = URL(string: "https://www.reddit.com/r/\(name)/top.json?t=month&limit=100&raw_json=1")
            else { continue }
            group.enter()
            session.dataTask(with: url) { data, response, error in
                defer { group.leave() }
                guard let data = data, error == nil,
                      (response as? HTTPURLResponse)?.statusCode == 200
                else {
                    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                    let reason = error?.localizedDescription ?? "HTTP \(status)"
                    NSLog("Reddit jokes from r/\(name) failed: \(reason)")
                    return
                }
                let jokes = Self.parse(data)
                lock.lock()
                collected += jokes
                lock.unlock()
            }.resume()
        }
        group.notify(queue: .main) { [weak self] in
            // Keep the last good batch when a refresh comes back empty.
            guard let self = self, self.isEnabled, !collected.isEmpty else { return }
            Jokes.reddit = collected
        }
    }

    private struct Listing: Decodable {
        struct Child: Decodable { let data: Post }
        struct Page: Decodable { let children: [Child] }
        let data: Page
    }

    private struct Post: Decodable {
        let title: String
        let selftext: String?
        let over_18: Bool?
        let spoiler: Bool?
        let stickied: Bool?
        let is_self: Bool?
        let score: Int?
    }

    private static func parse(_ data: Data) -> [String] {
        guard let listing = try? JSONDecoder().decode(Listing.self, from: data) else { return [] }
        return listing.data.children.compactMap { child in
            let post = child.data
            guard post.over_18 != true, post.spoiler != true, post.stickied != true,
                  post.is_self != false, (post.score ?? 0) >= minScore
            else { return nil }
            let title = post.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let body = (post.selftext ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let joke = body.isEmpty ? title : title + "\n" + body
            let lower = joke.lowercased()
            guard !title.isEmpty, joke.count <= maxLength,
                  !blocked.contains(where: { lower.contains($0) })
            else { return nil }
            return joke
        }
    }
}
