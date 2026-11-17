extends RefCounted

## Trouve l'objet physique lié à un nœud : le nœud lui-même s'il en est un
## (StaticBody, RigidBody, CharacterBody, Area...), sinon son parent direct
## (une forme de collision, un sprite d'un corps), sinon un enfant direct.


## null si [param node] n'a rien à voir avec la physique.
static func resolve(node: Node) -> Node:
	if node == null:
		return null
	if node is CollisionObject2D or node is CollisionObject3D:
		return node
	var parent: Node = node.get_parent()
	if parent is CollisionObject2D or parent is CollisionObject3D:
		return parent
	for child in node.get_children():
		if child is CollisionObject2D or child is CollisionObject3D:
			return child
	return null
