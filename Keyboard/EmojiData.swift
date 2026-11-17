//
//  EmojiData.swift
//  Every Unicode emoji up to Emoji 17.0 (about 1914), grouped like Apple's
//  emoji keyboard, plus WeChat's text codes. Generated from the emojibase data
//  set; skin-tone variants are not included.
//
//  Each run is tagged with the oldest iOS that can draw it, so phones on older
//  iOS never show empty boxes:
//    0 = iOS 15.0   1 = iOS 15.4   2 = iOS 16.4
//    3 = iOS 17.4   4 = iOS 18.4   5 = iOS 26.4
//

import Foundation

struct EmojiGroup {
    let title: String
    let tab: String          // label on the category bar
    let isText: Bool         // true = text codes such as "[Facepalm]"
    let items: [String]
}

struct EmojiSource {
    let title: String
    let tab: String
    let isText: Bool
    let runs: [(Int, String)]
    var extra: [String] = []
}

enum EmojiData {

    /// The groups this iPhone can display, built once.
    static let groups: [EmojiGroup] = {
        let level = supportedLevel
        return sources.map { source in
            var items: [String] = []
            for (needed, list) in source.runs where needed <= level {
                items += list.split(separator: " ").map(String.init)
            }
            items += source.extra
            return EmojiGroup(title: source.title, tab: source.tab,
                              isText: source.isText, items: items)
        }
    }()

    private static var supportedLevel: Int {
        let info = ProcessInfo.processInfo
        func atLeast(_ major: Int, _ minor: Int) -> Bool {
            info.isOperatingSystemAtLeast(
                OperatingSystemVersion(majorVersion: major, minorVersion: minor, patchVersion: 0))
        }
        if atLeast(26, 4) { return 5 }
        if atLeast(18, 4) { return 4 }
        if atLeast(17, 4) { return 3 }
        if atLeast(16, 4) { return 2 }
        if atLeast(15, 4) { return 1 }
        return 0
    }

    private static let sources: [EmojiSource] = [
        EmojiSource(title: "Smileys & People", tab: "😀", isText: false, runs: [
            (0, "😀 😃 😄 😁 😆 😅 🤣 😂 🙂 🙃"),
            (1, "🫠"),
            (0, "😉 😊 😇 🥰 😍 🤩 😘 😗 ☺️ 😚 😙 🥲 😋 😛 😜 🤪 😝 🤑 🤗 🤭"),
            (1, "🫢 🫣"),
            (0, "🤫 🤔"),
            (1, "🫡"),
            (0, "🤐 🤨 😐 😑 😶"),
            (1, "🫥"),
            (0, "😶‍🌫️ 😏 😒 🙄 😬 😮‍💨 🤥"),
            (2, "🫨"),
            (3, "🙂‍↔️ 🙂‍↕️"),
            (0, "😌 😔 😪 🤤 😴"),
            (4, "🫩"),
            (0, "😷 🤒 🤕 🤢 🤮 🤧 🥵 🥶 🥴 😵 😵‍💫 🤯 🤠 🥳 🥸 😎 🤓 🧐 😕"),
            (1, "🫤"),
            (0, "😟 🙁 ☹️ 😮 😯 😲 😳"),
            (5, "🫪"),
            (0, "🥺"),
            (1, "🥹"),
            (0, "😦 😧 😨 😰 😥 😢 😭 😱 😖 😣 😞 😓 😩 😫 🥱 😤 😡 😠 🤬 😈 👿 💀 ☠️ 💩 🤡 👹 👺 👻 👽 👾 🤖 😺 😸 😹 😻 😼 😽 🙀 😿 😾 🙈 🙉 🙊 💌 💘 💝 💖 💗 💓 💞 💕 💟 ❣️ 💔 ❤️‍🔥 ❤️‍🩹 ❤️"),
            (2, "🩷"),
            (0, "🧡 💛 💚 💙"),
            (2, "🩵"),
            (0, "💜 🤎 🖤"),
            (2, "🩶"),
            (0, "🤍 💋 💯 💢"),
            (5, "🫯"),
            (0, "💥 💫 💦 💨 🕳️ 💬 👁️‍🗨️ 🗨️ 🗯️ 💭 💤 👋 🤚 🖐️ ✋ 🖖"),
            (1, "🫱 🫲 🫳 🫴"),
            (2, "🫷 🫸"),
            (0, "👌 🤌 🤏 ✌️ 🤞"),
            (1, "🫰"),
            (0, "🤟 🤘 🤙 👈 👉 👆 🖕 👇 ☝️"),
            (1, "🫵"),
            (0, "👍 👎 ✊ 👊 🤛 🤜 👏 🙌"),
            (1, "🫶"),
            (0, "👐 🤲 🤝 🙏 ✍️ 💅 🤳 💪 🦾 🦿 🦵 🦶 👂 🦻 👃 🧠 🫀 🫁 🦷 🦴 👀 👁️ 👅 👄"),
            (1, "🫦"),
            (0, "👶 🧒 👦 👧 🧑 👱 👨 🧔 🧔‍♂️ 🧔‍♀️ 👨‍🦰 👨‍🦱 👨‍🦳 👨‍🦲 👩 👩‍🦰 🧑‍🦰 👩‍🦱 🧑‍🦱 👩‍🦳 🧑‍🦳 👩‍🦲 🧑‍🦲 👱‍♀️ 👱‍♂️ 🧓 👴 👵 🙍 🙍‍♂️ 🙍‍♀️ 🙎 🙎‍♂️ 🙎‍♀️ 🙅 🙅‍♂️ 🙅‍♀️ 🙆 🙆‍♂️ 🙆‍♀️ 💁 💁‍♂️ 💁‍♀️ 🙋 🙋‍♂️ 🙋‍♀️ 🧏 🧏‍♂️ 🧏‍♀️ 🙇 🙇‍♂️ 🙇‍♀️ 🤦 🤦‍♂️ 🤦‍♀️ 🤷 🤷‍♂️ 🤷‍♀️ 🧑‍⚕️ 👨‍⚕️ 👩‍⚕️ 🧑‍🎓 👨‍🎓 👩‍🎓 🧑‍🏫 👨‍🏫 👩‍🏫 🧑‍⚖️ 👨‍⚖️ 👩‍⚖️ 🧑‍🌾 👨‍🌾 👩‍🌾 🧑‍🍳 👨‍🍳 👩‍🍳 🧑‍🔧 👨‍🔧 👩‍🔧 🧑‍🏭 👨‍🏭 👩‍🏭 🧑‍💼 👨‍💼 👩‍💼 🧑‍🔬 👨‍🔬 👩‍🔬 🧑‍💻 👨‍💻 👩‍💻 🧑‍🎤 👨‍🎤 👩‍🎤 🧑‍🎨 👨‍🎨 👩‍🎨 🧑‍✈️ 👨‍✈️ 👩‍✈️ 🧑‍🚀 👨‍🚀 👩‍🚀 🧑‍🚒 👨‍🚒 👩‍🚒 👮 👮‍♂️ 👮‍♀️ 🕵️ 🕵️‍♂️ 🕵️‍♀️ 💂 💂‍♂️ 💂‍♀️ 🥷 👷 👷‍♂️ 👷‍♀️"),
            (1, "🫅"),
            (0, "🤴 👸 👳 👳‍♂️ 👳‍♀️ 👲 🧕 🤵 🤵‍♂️ 🤵‍♀️ 👰 👰‍♂️ 👰‍♀️ 🤰"),
            (1, "🫃 🫄"),
            (0, "🤱 👩‍🍼 👨‍🍼 🧑‍🍼 👼 🎅 🤶 🧑‍🎄 🦸 🦸‍♂️ 🦸‍♀️ 🦹 🦹‍♂️ 🦹‍♀️ 🧙 🧙‍♂️ 🧙‍♀️ 🧚 🧚‍♂️ 🧚‍♀️ 🧛 🧛‍♂️ 🧛‍♀️ 🧜 🧜‍♂️ 🧜‍♀️ 🧝 🧝‍♂️ 🧝‍♀️ 🧞 🧞‍♂️ 🧞‍♀️ 🧟 🧟‍♂️ 🧟‍♀️"),
            (1, "🧌"),
            (5, "🫈"),
            (0, "💆 💆‍♂️ 💆‍♀️ 💇 💇‍♂️ 💇‍♀️ 🚶 🚶‍♂️ 🚶‍♀️"),
            (3, "🚶‍➡️ 🚶‍♀️‍➡️ 🚶‍♂️‍➡️"),
            (0, "🧍 🧍‍♂️ 🧍‍♀️ 🧎 🧎‍♂️ 🧎‍♀️"),
            (3, "🧎‍➡️ 🧎‍♀️‍➡️ 🧎‍♂️‍➡️"),
            (0, "🧑‍🦯"),
            (3, "🧑‍🦯‍➡️"),
            (0, "👨‍🦯"),
            (3, "👨‍🦯‍➡️"),
            (0, "👩‍🦯"),
            (3, "👩‍🦯‍➡️"),
            (0, "🧑‍🦼"),
            (3, "🧑‍🦼‍➡️"),
            (0, "👨‍🦼"),
            (3, "👨‍🦼‍➡️"),
            (0, "👩‍🦼"),
            (3, "👩‍🦼‍➡️"),
            (0, "🧑‍🦽"),
            (3, "🧑‍🦽‍➡️"),
            (0, "👨‍🦽"),
            (3, "👨‍🦽‍➡️"),
            (0, "👩‍🦽"),
            (3, "👩‍🦽‍➡️"),
            (0, "🏃 🏃‍♂️ 🏃‍♀️"),
            (3, "🏃‍➡️ 🏃‍♀️‍➡️ 🏃‍♂️‍➡️"),
            (5, "🧑‍🩰"),
            (0, "💃 🕺 🕴️ 👯 👯‍♂️ 👯‍♀️ 🧖 🧖‍♂️ 🧖‍♀️ 🧗 🧗‍♂️ 🧗‍♀️ 🤺 🏇 ⛷️ 🏂 🏌️ 🏌️‍♂️ 🏌️‍♀️ 🏄 🏄‍♂️ 🏄‍♀️ 🚣 🚣‍♂️ 🚣‍♀️ 🏊 🏊‍♂️ 🏊‍♀️ ⛹️ ⛹️‍♂️ ⛹️‍♀️ 🏋️ 🏋️‍♂️ 🏋️‍♀️ 🚴 🚴‍♂️ 🚴‍♀️ 🚵 🚵‍♂️ 🚵‍♀️ 🤸 🤸‍♂️ 🤸‍♀️ 🤼 🤼‍♂️ 🤼‍♀️ 🤽 🤽‍♂️ 🤽‍♀️ 🤾 🤾‍♂️ 🤾‍♀️ 🤹 🤹‍♂️ 🤹‍♀️ 🧘 🧘‍♂️ 🧘‍♀️ 🛀 🛌 🧑‍🤝‍🧑 👭 👫 👬 💏 👩‍❤️‍💋‍👨 👨‍❤️‍💋‍👨 👩‍❤️‍💋‍👩 💑 👩‍❤️‍👨 👨‍❤️‍👨 👩‍❤️‍👩 👨‍👩‍👦 👨‍👩‍👧 👨‍👩‍👧‍👦 👨‍👩‍👦‍👦 👨‍👩‍👧‍👧 👨‍👨‍👦 👨‍👨‍👧 👨‍👨‍👧‍👦 👨‍👨‍👦‍👦 👨‍👨‍👧‍👧 👩‍👩‍👦 👩‍👩‍👧 👩‍👩‍👧‍👦 👩‍👩‍👦‍👦 👩‍👩‍👧‍👧 👨‍👦 👨‍👦‍👦 👨‍👧 👨‍👧‍👦 👨‍👧‍👧 👩‍👦 👩‍👦‍👦 👩‍👧 👩‍👧‍👦 👩‍👧‍👧 🗣️ 👤 👥 🫂 👪"),
            (3, "🧑‍🧑‍🧒 🧑‍🧑‍🧒‍🧒 🧑‍🧒 🧑‍🧒‍🧒"),
            (0, "👣"),
            (4, "🫆"),
        ]),
        EmojiSource(title: "Animals & Nature", tab: "🐻", isText: false, runs: [
            (0, "🐵 🐒 🦍 🦧 🐶 🐕 🦮 🐕‍🦺 🐩 🐺 🦊 🦝 🐱 🐈 🐈‍⬛ 🦁 🐯 🐅 🐆 🐴"),
            (2, "🫎 🫏"),
            (0, "🐎 🦄 🦓 🦌 🦬 🐮 🐂 🐃 🐄 🐷 🐖 🐗 🐽 🐏 🐑 🐐 🐪 🐫 🦙 🦒 🐘 🦣 🦏 🦛 🐭 🐁 🐀 🐹 🐰 🐇 🐿️ 🦫 🦔 🦇 🐻 🐻‍❄️ 🐨 🐼 🦥 🦦 🦨 🦘 🦡 🐾 🦃 🐔 🐓 🐣 🐤 🐥 🐦 🐧 🕊️ 🦅 🦆 🦢 🦉 🦤 🪶 🦩 🦚 🦜"),
            (2, "🪽 🐦‍⬛ 🪿"),
            (3, "🐦‍🔥"),
            (0, "🐸 🐊 🐢 🦎 🐍 🐲 🐉 🦕 🦖 🐳 🐋 🐬"),
            (5, "🫍"),
            (0, "🦭 🐟 🐠 🐡 🦈 🐙 🐚"),
            (1, "🪸"),
            (2, "🪼"),
            (0, "🦀 🦞 🦐 🦑 🦪 🐌 🦋 🐛 🐜 🐝 🪲 🐞 🦗 🪳 🕷️ 🕸️ 🦂 🦟 🪰 🪱 🦠 💐 🌸 💮"),
            (1, "🪷"),
            (0, "🏵️ 🌹 🥀 🌺 🌻 🌼 🌷"),
            (2, "🪻"),
            (0, "🌱 🪴 🌲 🌳 🌴 🌵 🌾 🌿 ☘️ 🍀 🍁 🍂 🍃"),
            (1, "🪹 🪺"),
            (0, "🍄"),
            (4, "🪾"),
        ]),
        EmojiSource(title: "Food & Drink", tab: "🍔", isText: false, runs: [
            (0, "🍇 🍈 🍉 🍊 🍋"),
            (3, "🍋‍🟩"),
            (0, "🍌 🍍 🥭 🍎 🍏 🍐 🍑 🍒 🍓 🫐 🥝 🍅 🫒 🥥 🥑 🍆 🥔 🥕 🌽 🌶️ 🫑 🥒 🥬 🥦 🧄 🧅 🥜"),
            (1, "🫘"),
            (0, "🌰"),
            (2, "🫚 🫛"),
            (3, "🍄‍🟫"),
            (4, "🫜"),
            (0, "🍞 🥐 🥖 🫓 🥨 🥯 🥞 🧇 🧀 🍖 🍗 🥩 🥓 🍔 🍟 🍕 🌭 🥪 🌮 🌯 🫔 🥙 🧆 🥚 🍳 🥘 🍲 🫕 🥣 🥗 🍿 🧈 🧂 🥫 🍱 🍘 🍙 🍚 🍛 🍜 🍝 🍠 🍢 🍣 🍤 🍥 🥮 🍡 🥟 🥠 🥡 🍦 🍧 🍨 🍩 🍪 🎂 🍰 🧁 🥧 🍫 🍬 🍭 🍮 🍯 🍼 🥛 ☕ 🫖 🍵 🍶 🍾 🍷 🍸 🍹 🍺 🍻 🥂 🥃"),
            (1, "🫗"),
            (0, "🥤 🧋 🧃 🧉 🧊 🥢 🍽️ 🍴 🥄 🔪"),
            (1, "🫙"),
            (0, "🏺"),
        ]),
        EmojiSource(title: "Activity", tab: "⚽", isText: false, runs: [
            (0, "🎃 🎄 🎆 🎇 🧨 ✨ 🎈 🎉 🎊 🎋 🎍 🎎 🎏 🎐 🎑 🧧 🎀 🎁 🎗️ 🎟️ 🎫 🎖️ 🏆 🏅 🥇 🥈 🥉 ⚽ ⚾ 🥎 🏀 🏐 🏈 🏉 🎾 🥏 🎳 🏏 🏑 🏒 🥍 🏓 🏸 🥊 🥋 🥅 ⛳ ⛸️ 🎣 🤿 🎽 🎿 🛷 🥌 🎯 🪀 🪁 🔫 🎱 🔮 🪄 🎮 🕹️ 🎰 🎲 🧩 🧸 🪅"),
            (1, "🪩"),
            (0, "🪆 ♠️ ♥️ ♦️ ♣️ ♟️ 🃏 🀄 🎴 🎭 🖼️ 🎨 🧵 🪡 🧶 🪢"),
        ]),
        EmojiSource(title: "Travel & Places", tab: "🚗", isText: false, runs: [
            (0, "🌍 🌎 🌏 🌐 🗺️ 🗾 🧭 🏔️ ⛰️"),
            (5, "🛘"),
            (0, "🌋 🗻 🏕️ 🏖️ 🏜️ 🏝️ 🏞️ 🏟️ 🏛️ 🏗️ 🧱 🪨 🪵 🛖 🏘️ 🏚️ 🏠 🏡 🏢 🏣 🏤 🏥 🏦 🏨 🏩 🏪 🏫 🏬 🏭 🏯 🏰 💒 🗼 🗽 ⛪ 🕌 🛕 🕍 ⛩️ 🕋 ⛲ ⛺ 🌁 🌃 🏙️ 🌄 🌅 🌆 🌇 🌉 ♨️ 🎠"),
            (1, "🛝"),
            (0, "🎡 🎢 💈 🎪 🚂 🚃 🚄 🚅 🚆 🚇 🚈 🚉 🚊 🚝 🚞 🚋 🚌 🚍 🚎 🚐 🚑 🚒 🚓 🚔 🚕 🚖 🚗 🚘 🚙 🛻 🚚 🚛 🚜 🏎️ 🏍️ 🛵 🦽 🦼 🛺 🚲 🛴 🛹 🛼 🚏 🛣️ 🛤️ 🛢️ ⛽"),
            (1, "🛞"),
            (0, "🚨 🚥 🚦 🛑 🚧 ⚓"),
            (1, "🛟"),
            (0, "⛵ 🛶 🚤 🛳️ ⛴️ 🛥️ 🚢 ✈️ 🛩️ 🛫 🛬 🪂 💺 🚁 🚟 🚠 🚡 🛰️ 🚀 🛸 🛎️ 🧳 ⌛ ⏳ ⌚ ⏰ ⏱️ ⏲️ 🕰️ 🕛 🕧 🕐 🕜 🕑 🕝 🕒 🕞 🕓 🕟 🕔 🕠 🕕 🕡 🕖 🕢 🕗 🕣 🕘 🕤 🕙 🕥 🕚 🕦 🌑 🌒 🌓 🌔 🌕 🌖 🌗 🌘 🌙 🌚 🌛 🌜 🌡️ ☀️ 🌝 🌞 🪐 ⭐ 🌟 🌠 🌌 ☁️ ⛅ ⛈️ 🌤️ 🌥️ 🌦️ 🌧️ 🌨️ 🌩️ 🌪️ 🌫️ 🌬️ 🌀 🌈 🌂 ☂️ ☔ ⛱️ ⚡ ❄️ ☃️ ⛄ ☄️ 🔥 💧 🌊"),
        ]),
        EmojiSource(title: "Objects", tab: "💡", isText: false, runs: [
            (0, "👓 🕶️ 🥽 🥼 🦺 👔 👕 👖 🧣 🧤 🧥 🧦 👗 👘 🥻 🩱 🩲 🩳 👙 👚"),
            (2, "🪭"),
            (0, "👛 👜 👝 🛍️ 🎒 🩴 👞 👟 🥾 🥿 👠 👡 🩰 👢"),
            (2, "🪮"),
            (0, "👑 👒 🎩 🎓 🧢 🪖 ⛑️ 📿 💄 💍 💎 🔇 🔈 🔉 🔊 📢 📣 📯 🔔 🔕 🎼 🎵 🎶 🎙️ 🎚️ 🎛️ 🎤 🎧 📻 🎷 🎺"),
            (5, "🪊"),
            (0, "🪗 🎸 🎹 🎻 🪕 🥁 🪘"),
            (2, "🪇 🪈"),
            (4, "🪉"),
            (0, "📱 📲 ☎️ 📞 📟 📠 🔋"),
            (1, "🪫"),
            (0, "🔌 💻 🖥️ 🖨️ ⌨️ 🖱️ 🖲️ 💽 💾 💿 📀 🧮 🎥 🎞️ 📽️ 🎬 📺 📷 📸 📹 📼 🔍 🔎 🕯️ 💡 🔦 🏮 🪔 📔 📕 📖 📗 📘 📙 📚 📓 📒 📃 📜 📄 📰 🗞️ 📑 🔖 🏷️ 🪙 💰"),
            (5, "🪎"),
            (0, "💴 💵 💶 💷 💸 💳 🧾 💹 ✉️ 📧 📨 📩 📤 📥 📦 📫 📪 📬 📭 📮 🗳️ ✏️ ✒️ 🖋️ 🖊️ 🖌️ 🖍️ 📝 💼 📁 📂 🗂️ 📅 📆 🗒️ 🗓️ 📇 📈 📉 📊 📋 📌 📍 📎 🖇️ 📏 📐 ✂️ 🗃️ 🗄️ 🗑️ 🔒 🔓 🔏 🔐 🔑 🗝️ 🔨 🪓 ⛏️ ⚒️ 🛠️ 🗡️ ⚔️ 💣 🪃 🏹 🛡️ 🪚 🔧 🪛 🔩 ⚙️ 🗜️ ⚖️ 🦯 🔗"),
            (3, "⛓️‍💥"),
            (0, "⛓️ 🪝 🧰 🧲 🪜"),
            (4, "🪏"),
            (0, "⚗️ 🧪 🧫 🧬 🔬 🔭 📡 💉 🩸 💊 🩹"),
            (1, "🩼"),
            (0, "🩺"),
            (1, "🩻"),
            (0, "🚪 🛗 🪞 🪟 🛏️ 🛋️ 🪑 🚽 🪠 🚿 🛁 🪤 🪒 🧴 🧷 🧹 🧺 🧻 🪣 🧼"),
            (1, "🫧"),
            (0, "🪥 🧽 🧯 🛒 🚬 ⚰️ 🪦 ⚱️ 🧿"),
            (1, "🪬"),
            (0, "🗿 🪧"),
            (1, "🪪"),
        ]),
        EmojiSource(title: "Symbols", tab: "🔣", isText: false, runs: [
            (0, "🏧 🚮 🚰 ♿ 🚹 🚺 🚻 🚼 🚾 🛂 🛃 🛄 🛅 ⚠️ 🚸 ⛔ 🚫 🚳 🚭 🚯 🚱 🚷 📵 🔞 ☢️ ☣️ ⬆️ ↗️ ➡️ ↘️ ⬇️ ↙️ ⬅️ ↖️ ↕️ ↔️ ↩️ ↪️ ⤴️ ⤵️ 🔃 🔄 🔙 🔚 🔛 🔜 🔝 🛐 ⚛️ 🕉️ ✡️ ☸️ ☯️ ✝️ ☦️ ☪️ ☮️ 🕎 🔯"),
            (2, "🪯"),
            (0, "♈ ♉ ♊ ♋ ♌ ♍ ♎ ♏ ♐ ♑ ♒ ♓ ⛎ 🔀 🔁 🔂 ▶️ ⏩ ⏭️ ⏯️ ◀️ ⏪ ⏮️ 🔼 ⏫ 🔽 ⏬ ⏸️ ⏹️ ⏺️ ⏏️ 🎦 🔅 🔆 📶"),
            (2, "🛜"),
            (0, "📳 📴 ♀️ ♂️ ⚧️ ✖️ ➕ ➖ ➗"),
            (1, "🟰"),
            (0, "♾️ ‼️ ⁉️ ❓ ❔ ❕ ❗ 〰️ 💱 💲 ⚕️ ♻️ ⚜️ 🔱 📛 🔰 ⭕ ✅ ☑️ ✔️ ❌ ❎ ➰ ➿ 〽️ ✳️ ✴️ ❇️ ©️ ®️ ™️"),
            (4, "🫟"),
            (0, "#️⃣ *️⃣ 0️⃣ 1️⃣ 2️⃣ 3️⃣ 4️⃣ 5️⃣ 6️⃣ 7️⃣ 8️⃣ 9️⃣ 🔟 🔠 🔡 🔢 🔣 🔤 🅰️ 🆎 🅱️ 🆑 🆒 🆓 ℹ️ 🆔 Ⓜ️ 🆕 🆖 🅾️ 🆗 🅿️ 🆘 🆙 🆚 🈁 🈂️ 🈷️ 🈶 🈯 🉐 🈹 🈚 🈲 🉑 🈸 🈴 🈳 ㊗️ ㊙️ 🈺 🈵 🔴 🟠 🟡 🟢 🔵 🟣 🟤 ⚫ ⚪ 🟥 🟧 🟨 🟩 🟦 🟪 🟫 ⬛ ⬜ ◼️ ◻️ ◾ ◽ ▪️ ▫️ 🔶 🔷 🔸 🔹 🔺 🔻 💠 🔘 🔳 🔲"),
        ]),
        EmojiSource(title: "Flags", tab: "🏳️", isText: false, runs: [
            (0, "🏁 🚩 🎌 🏴 🏳️ 🏳️‍🌈 🏳️‍⚧️ 🏴‍☠️ 🇦🇨 🇦🇩 🇦🇪 🇦🇫 🇦🇬 🇦🇮 🇦🇱 🇦🇲 🇦🇴 🇦🇶 🇦🇷 🇦🇸 🇦🇹 🇦🇺 🇦🇼 🇦🇽 🇦🇿 🇧🇦 🇧🇧 🇧🇩 🇧🇪 🇧🇫 🇧🇬 🇧🇭 🇧🇮 🇧🇯 🇧🇱 🇧🇲 🇧🇳 🇧🇴 🇧🇶 🇧🇷 🇧🇸 🇧🇹 🇧🇻 🇧🇼 🇧🇾 🇧🇿 🇨🇦 🇨🇨 🇨🇩 🇨🇫 🇨🇬 🇨🇭 🇨🇮 🇨🇰 🇨🇱 🇨🇲 🇨🇳 🇨🇴 🇨🇵"),
            (4, "🇨🇶"),
            (0, "🇨🇷 🇨🇺 🇨🇻 🇨🇼 🇨🇽 🇨🇾 🇨🇿 🇩🇪 🇩🇬 🇩🇯 🇩🇰 🇩🇲 🇩🇴 🇩🇿 🇪🇦 🇪🇨 🇪🇪 🇪🇬 🇪🇭 🇪🇷 🇪🇸 🇪🇹 🇪🇺 🇫🇮 🇫🇯 🇫🇰 🇫🇲 🇫🇴 🇫🇷 🇬🇦 🇬🇧 🇬🇩 🇬🇪 🇬🇫 🇬🇬 🇬🇭 🇬🇮 🇬🇱 🇬🇲 🇬🇳 🇬🇵 🇬🇶 🇬🇷 🇬🇸 🇬🇹 🇬🇺 🇬🇼 🇬🇾 🇭🇰 🇭🇲 🇭🇳 🇭🇷 🇭🇹 🇭🇺 🇮🇨 🇮🇩 🇮🇪 🇮🇱 🇮🇲 🇮🇳 🇮🇴 🇮🇶 🇮🇷 🇮🇸 🇮🇹 🇯🇪 🇯🇲 🇯🇴 🇯🇵 🇰🇪 🇰🇬 🇰🇭 🇰🇮 🇰🇲 🇰🇳 🇰🇵 🇰🇷 🇰🇼 🇰🇾 🇰🇿 🇱🇦 🇱🇧 🇱🇨 🇱🇮 🇱🇰 🇱🇷 🇱🇸 🇱🇹 🇱🇺 🇱🇻 🇱🇾 🇲🇦 🇲🇨 🇲🇩 🇲🇪 🇲🇫 🇲🇬 🇲🇭 🇲🇰 🇲🇱 🇲🇲 🇲🇳 🇲🇴 🇲🇵 🇲🇶 🇲🇷 🇲🇸 🇲🇹 🇲🇺 🇲🇻 🇲🇼 🇲🇽 🇲🇾 🇲🇿 🇳🇦 🇳🇨 🇳🇪 🇳🇫 🇳🇬 🇳🇮 🇳🇱 🇳🇴 🇳🇵 🇳🇷 🇳🇺 🇳🇿 🇴🇲 🇵🇦 🇵🇪 🇵🇫 🇵🇬 🇵🇭 🇵🇰 🇵🇱 🇵🇲 🇵🇳 🇵🇷 🇵🇸 🇵🇹 🇵🇼 🇵🇾 🇶🇦 🇷🇪 🇷🇴 🇷🇸 🇷🇺 🇷🇼 🇸🇦 🇸🇧 🇸🇨 🇸🇩 🇸🇪 🇸🇬 🇸🇭 🇸🇮 🇸🇯 🇸🇰 🇸🇱 🇸🇲 🇸🇳 🇸🇴 🇸🇷 🇸🇸 🇸🇹 🇸🇻 🇸🇽 🇸🇾 🇸🇿 🇹🇦 🇹🇨 🇹🇩 🇹🇫 🇹🇬 🇹🇭 🇹🇯 🇹🇰 🇹🇱 🇹🇲 🇹🇳 🇹🇴 🇹🇷 🇹🇹 🇹🇻 🇹🇼 🇹🇿 🇺🇦 🇺🇬 🇺🇲 🇺🇳 🇺🇸 🇺🇾 🇺🇿 🇻🇦 🇻🇨 🇻🇪 🇻🇬 🇻🇮 🇻🇳 🇻🇺 🇼🇫 🇼🇸 🇽🇰 🇾🇪 🇾🇹 🇿🇦 🇿🇲 🇿🇼 🏴󠁧󠁢󠁥󠁮󠁧󠁿 🏴󠁧󠁢󠁳󠁣󠁴󠁿 🏴󠁧󠁢󠁷󠁬󠁳󠁿"),
        ]),
        EmojiSource(title: "WeChat (works inside WeChat only)", tab: "💬", isText: true, runs: [
            (0, "[Facepalm] [捂脸] [Aaagh!] [Angry] [Awesome] [Awkward] [Bah！R] [Bah！L] [Beckon] [Beer] [Blessing] [Blush] [Bomb] [Boring] [Broken] [BrokenHeart] [Bye] [Cake] [Chuckle] [Clap] [Cleaver] [Coffee] [Commando] [Concerned] [CoolGuy] [Cry] [Determined] [Dizzy] [Doge] [Drool] [Drowsy] [Duh] [Emm] [Fireworks] [Fist] [Flushed] [Frown] [Gift] [GoForIt] [Grimace] [Grin] [Hammer] [Happy] [Heart] [Hey] [Hug] [Hurt] [Joyful] [KeepFighting] [Kiss] [Laugh] [LetMeSee] [Lips] [Lol] [Moon] [MyBad] [NoProb] [NosePick] [OK] [OMG] [Onlooker] [Packet] [Panic] [Party] [Peace] [Pig] [Pooh-pooh] [Poop] [Puke] [Respect] [Rose] [Salute] [Scold] [Scowl] [Scream] [Shake] [Shhh] [Shocked] [Shrunken] [Shy] [Sick] [Sigh] [Silent] [Skull] [Sleep] [Slight] [Sly] [Smart] [Smile] [Smirk] [Smug] [Sob] [Speechless] [Sun] [Surprise] [Sweat] [Sweats] [TearingUp] [Terror] [ThumbsDown] [ThumbsUp] [Toasted] [Tongue] [Tremble] [Trick] [Twirl] [Watermelon] [Waddle] [Whimper] [Wilt] [Worship] [Wow] [Yawn] [Yeah!]"),
        ], extra: ["[Let Down]"]),
    ]
}
