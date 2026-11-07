using UnityEngine;

public class ArenaCombat : MonoBehaviour
{
    public ArenaFighter owner;
    public ArenaProjectile projectilePrefab;
    public Transform muzzle;
    public float fireInterval = 0.24f;
    public float superRadius = 3.6f;
    public float superDamage = 75f;
    public LayerMask fighters;
    private float nextFire;
    private float charge;
    public float SuperCharge => charge;

    public void Fire(Vector2 aim)
    {
        if (aim.sqrMagnitude < 0.04f || Time.time < nextFire || !projectilePrefab) return;
        nextFire = Time.time + fireInterval;
        Vector2 dir = aim.normalized;
        var projectile = Instantiate(projectilePrefab, muzzle ? muzzle.position : transform.position, Quaternion.identity);
        projectile.Launch(dir, owner, this);
    }
    public void RegisterHit() { charge = Mathf.Min(1f, charge + 0.08f); }
    public void ActivateSuper()
    {
        if (charge < 1f) return;
        charge = 0;
        foreach (var collider in Physics2D.OverlapCircleAll(transform.position, superRadius, fighters))
        {
            var target = collider.GetComponent<ArenaFighter>();
            if (target && target != owner) target.Damage(superDamage);
        }
    }
}

public class ArenaProjectile : MonoBehaviour
{
    public float speed = 12f;
    public float damage = 25f;
    public float lifetime = 2.5f;
    private Vector2 direction;
    private ArenaFighter owner;
    private ArenaCombat source;
    public void Launch(Vector2 aim, ArenaFighter shooter, ArenaCombat combat)
    {
        direction = aim.normalized;
        owner = shooter;
        source = combat;
        Destroy(gameObject, lifetime);
    }
    void Update() { transform.position += (Vector3)(direction * speed * Time.deltaTime); }
    void OnTriggerEnter2D(Collider2D other)
    {
        var target = other.GetComponent<ArenaFighter>();
        if (target == owner) return;
        if (target) { target.Damage(damage); if (source) source.RegisterHit(); }
        Destroy(gameObject);
    }
}
