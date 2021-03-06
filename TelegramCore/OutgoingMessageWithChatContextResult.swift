import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

private func aspectFitSize(_ size: CGSize, to: CGSize) -> CGSize {
    let scale = min(to.width / max(1.0, size.width), to.height / max(1.0, size.height))
    return CGSize(width: floor(size.width * scale), height: floor(size.height * scale))
}

public func outgoingMessageWithChatContextResult(to peerId: PeerId, results: ChatContextResultCollection, result: ChatContextResult) -> EnqueueMessage? {
    var attributes: [MessageAttribute] = []
    attributes.append(OutgoingChatContextResultMessageAttribute(queryId: result.queryId, id: result.id))
    attributes.append(InlineBotMessageAttribute(peerId: results.botId, title: nil))
    
    switch result.message {
        case let .auto(caption, entities, replyMarkup):
            if let entities = entities {
                attributes.append(entities)
            }
            if let replyMarkup = replyMarkup {
                attributes.append(replyMarkup)
            }
            switch result {
                case let .internalReference(_, id, type, title, description, image, file, message):
                    if type == "game" {
                        if peerId.namespace == Namespaces.Peer.SecretChat {
                            let filteredAttributes = attributes.filter { attribute in
                                if let _ = attribute as? ReplyMarkupMessageAttribute {
                                    return false
                                }
                                return true
                            }
                            if let media: Media = file ?? image {
                                return .message(text: caption, attributes: filteredAttributes, mediaReference: .standalone(media: media), replyToMessageId: nil, localGroupingKey: nil)
                            } else {
                                return .message(text: caption, attributes: filteredAttributes, mediaReference: nil, replyToMessageId: nil, localGroupingKey: nil)
                            }
                        } else {
                            return .message(text: "", attributes: attributes, mediaReference: .standalone(media: TelegramMediaGame(gameId: 0, accessHash: 0, name: "", title: title ?? "", description: description ?? "", image: image, file: file)), replyToMessageId: nil, localGroupingKey: nil)
                        }
                    } else if let file = file, type == "gif" {
                        return .message(text: caption, attributes: attributes, mediaReference: .standalone(media: file), replyToMessageId: nil, localGroupingKey: nil)
                    } else if let image = image {
                        return .message(text: caption, attributes: attributes, mediaReference: .standalone(media: image), replyToMessageId: nil, localGroupingKey: nil)
                    } else if let file = file {
                        return .message(text: caption, attributes: attributes, mediaReference: .standalone(media: file), replyToMessageId: nil, localGroupingKey: nil)
                    } else {
                        return nil
                    }
                case let .externalReference(_, id, type, title, description, url, content, thumbnail, message):
                    if type == "photo" {
                        if let thumbnail = thumbnail {
                            var randomId: Int64 = 0
                            arc4random_buf(&randomId, 8)
                            let thumbnailResource = thumbnail.resource
                            let imageDimensions = thumbnail.dimensions ?? CGSize(width: 128.0, height: 128.0)
                            let tmpImage = TelegramMediaImage(imageId: MediaId(namespace: Namespaces.Media.LocalImage, id: randomId), representations: [TelegramMediaImageRepresentation(dimensions: imageDimensions, resource: thumbnailResource)], reference: nil, partialReference: nil)
                            return .message(text: caption, attributes: attributes, mediaReference: .standalone(media: tmpImage), replyToMessageId: nil, localGroupingKey: nil)
                        } else {
                            return .message(text: caption, attributes: attributes, mediaReference: nil, replyToMessageId: nil, localGroupingKey: nil)
                        }
                    } else if type == "document" || type == "gif" || type == "audio" || type == "voice" {
                        var previewRepresentations: [TelegramMediaImageRepresentation] = []
                        if let thumbnail = thumbnail {
                            var randomId: Int64 = 0
                            arc4random_buf(&randomId, 8)
                            let thumbnailResource = thumbnail.resource
                            previewRepresentations.append(TelegramMediaImageRepresentation(dimensions: thumbnail.dimensions ?? CGSize(width: 128.0, height: 128.0), resource: thumbnailResource))
                        }
                        var fileName = "file"
                        if let content = content {
                            var contentUrl: String?
                            if let resource = content.resource as? HttpReferenceMediaResource {
                                contentUrl = resource.url
                            } else if let resource = content.resource as? WebFileReferenceMediaResource {
                                contentUrl = resource.url
                            }
                            if let contentUrl = contentUrl, let url = URL(string: contentUrl) {
                                if !url.lastPathComponent.isEmpty {
                                    fileName = url.lastPathComponent
                                }
                            }
                        }
                        
                        var fileAttributes: [TelegramMediaFileAttribute] = []
                        fileAttributes.append(.FileName(fileName: fileName))
                        
                        if type == "gif" {
                            fileAttributes.append(.Animated)
                        }
                        
                        if let dimensions = content?.dimensions {
                            fileAttributes.append(.ImageSize(size: dimensions))
                            if type == "gif" {
                                fileAttributes.append(.Video(duration: Int(Int32(content?.duration ?? 0)), size: dimensions, flags: []))
                            }
                        }
                        
                        if type == "audio" || type == "voice" {
                            fileAttributes.append(.Audio(isVoice: type == "voice", duration: Int(Int32(content?.duration ?? 0)), title: title, performer: description, waveform: nil))
                        }
                        
                        var randomId: Int64 = 0
                        arc4random_buf(&randomId, 8)
                        
                        let resource: TelegramMediaResource
                        if peerId.namespace == Namespaces.Peer.SecretChat, let webResource = content?.resource as? WebFileReferenceMediaResource {
                            resource = webResource
                        } else {
                            resource = EmptyMediaResource()
                        }
                        
                        let file = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: randomId), partialReference: nil, resource: resource, previewRepresentations: previewRepresentations, mimeType: content?.mimeType ?? "application/binary", size: nil, attributes: fileAttributes)
                        return .message(text: caption, attributes: attributes, mediaReference: .standalone(media: file), replyToMessageId: nil, localGroupingKey: nil)
                    } else {
                        return .message(text: caption, attributes: attributes, mediaReference: nil, replyToMessageId: nil, localGroupingKey: nil)
                    }
            }
        case let .text(text, entities, disableUrlPreview, replyMarkup):
            if let entities = entities {
                attributes.append(entities)
            }
            if let replyMarkup = replyMarkup {
                attributes.append(replyMarkup)
            }
            return .message(text: text, attributes: attributes, mediaReference: nil, replyToMessageId: nil, localGroupingKey: nil)
        case let .mapLocation(media, replyMarkup):
            if let replyMarkup = replyMarkup {
                attributes.append(replyMarkup)
            }
            return .message(text: "", attributes: attributes, mediaReference: .standalone(media: media), replyToMessageId: nil, localGroupingKey: nil)
        case let .contact(media, replyMarkup):
            if let replyMarkup = replyMarkup {
                attributes.append(replyMarkup)
            }
            return .message(text: "", attributes: attributes, mediaReference: .standalone(media: media), replyToMessageId: nil, localGroupingKey: nil)
    }
}
