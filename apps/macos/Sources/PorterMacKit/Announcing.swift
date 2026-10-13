import PorterPanelModel

@MainActor
public protocol Announcing: AnyObject {
    func announce(_ batch: CompletionBatch)
}
