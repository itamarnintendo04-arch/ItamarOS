using UnityEngine;

[RequireComponent(typeof(ArenaFighter))]
public class ArenaEnemyAI : MonoBehaviour
{
    public Transform target;
    public ArenaCombat weapon;
    public float stopDistance = 3.8f;
    private ArenaFighter fighter;
    void Awake() { fighter = GetComponent<ArenaFighter>(); }
    void Update()
    {
        if (!target || fighter.health <= 0) return;
        Vector2 toTarget = target.position - transform.position;
        if (toTarget.magnitude > stopDistance)
            transform.position += (Vector3)(toTarget.normalized * fighter.speed * Time.deltaTime);
        if (weapon) weapon.Fire(toTarget);
    }
}
