#if os(iOS)
import SwiftUI
import Foundation

// A small view keeps the SwiftUI type checker from having to infer the
// complete messaging page, which previously caused Xcode exit code 65.
struct ItamarMessageBubbleView: View {
    let message: ItamarCloudMessage
    let ownMessage: Bool
    let receipt: ItamarReceiptSummary?
    let reactionCounts: [ItamarReactionCount]
    let repliedText: String?
    let onReply: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onViewOnce: () -> Void
    let onFile: () -> Void
    let onReact: (String) -> Void
    let onReport: () -> Void
    let onBlock: () -> Void

    private var deleted: Bool { message.deleted_at != nil }
    private var hasRead: Bool { (receipt?.read ?? 0)>0 }
    private var hasDelivered: Bool { (receipt?.delivered ?? 0)>0 }
    private var link: URL? {
        let detector=try? NSDataDetector(types:NSTextCheckingResult.CheckingType.link.rawValue)
        let text=message.body
        let range=NSRange(text.startIndex..<text.endIndex,in:text)
        return detector?.matches(in:text,range:range)
            .compactMap { $0.url }
            .first { $0.scheme == "https" || $0.scheme == "http" }
    }

    var body: some View {
        HStack {
            if ownMessage { Spacer(minLength:44) }
            VStack(alignment:.leading,spacing:6) {
                if let repliedText, !repliedText.isEmpty {
                    HStack {
                        Rectangle().fill(.blue).frame(width:3)
                        Text(repliedText).font(.caption)
                            .lineLimit(2).foregroundStyle(.secondary)
                    }
                }
                Text(deleted ? "Message deleted" : message.body)
                    .opacity(deleted ? 0.6 : 1)
                    .frame(maxWidth:.infinity,alignment:.leading)
                if let url=link, !deleted, message.is_view_once != true {
                    Link("Open shared link",destination:url).font(.caption)
                }
                if message.is_view_once == true && !ownMessage && !deleted {
                    Button("Open once",systemImage:"eye",action:onViewOnce)
                        .buttonStyle(.bordered)
                }
                if message.attachment_path != nil && !deleted {
                    Button("Download attachment",systemImage:"paperclip",action:onFile)
                        .buttonStyle(.bordered)
                }
                if !deleted && !reactionCounts.isEmpty {
                    HStack(spacing:6) {
                        ForEach(reactionCounts) { item in
                            Text(item.emoji+" "+String(item.count))
                                .font(.caption)
                        }
                    }
                }
                HStack(spacing:5) {
                    Text(String(message.created_at.prefix(16))
                        .replacingOccurrences(of:"T",with:" "))
                    if message.edited_at != nil && !deleted { Text("Edited") }
                    if message.expires_at != nil && !deleted {
                        Image(systemName:"timer")
                            .accessibilityLabel("Disappearing message")
                    }
                    if ownMessage {
                        Text(hasRead ? "✓✓" : hasDelivered ? "✓✓" : "✓")
                            .fontWeight(.bold)
                            .foregroundStyle(hasRead ? Color.blue : Color.secondary)
                            .accessibilityLabel(hasRead ? "Read" : hasDelivered ? "Delivered" : "Sent")
                    }
                }
                .font(.caption2).foregroundStyle(.secondary)
            }
            .padding(12)
            .background(ownMessage ? Color.blue.opacity(0.16) : Color.gray.opacity(0.12),
                        in:RoundedRectangle(cornerRadius:14))
            .frame(maxWidth:310)
            .contextMenu {
                if !deleted {
                    Menu("React") {
                        ForEach(["👍","❤️","😂","😮","😢","🙏","🎉"],id:\.self) { emoji in
                            Button(emoji) { onReact(emoji) }
                        }
                    }
                    if message.is_view_once != true {
                        Button("Reply",systemImage:"arrowshape.turn.up.left",action:onReply)
                    }
                    if ownMessage {
                        if message.attachment_path == nil && message.is_view_once != true {
                            Button("Edit",systemImage:"pencil",action:onEdit)
                        }
                        Button("Delete",systemImage:"trash",role:.destructive,action:onDelete)
                    } else {
                        Button("Report",systemImage:"flag",action:onReport)
                        Button("Block user",systemImage:"hand.raised",action:onBlock)
                    }
                }
            }
            if !ownMessage { Spacer(minLength:44) }
        }.id(message.id)
    }
}
#endif
