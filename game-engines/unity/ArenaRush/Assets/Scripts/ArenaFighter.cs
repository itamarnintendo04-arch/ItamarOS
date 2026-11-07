using UnityEngine;
using System;

public class ArenaFighter : MonoBehaviour
{
    public bool isPlayer;
    public float maxHealth = 100f;
    public float speed = 5f;
    public float health;
    public event Action<ArenaFighter> Died;
    private Rigidbody2D body;
    private Vector2 input;

    void Awake() { health = maxHealth; body = GetComponent<Rigidbody2D>(); }
    public void SetMovement(Vector2 movement) { input = Vector2.ClampMagnitude(movement, 1f); }
    void FixedUpdate()
    {
        if (!isPlayer || health <= 0) return;
        Vector2 delta = input * speed * Time.fixedDeltaTime;
        if (body) body.MovePosition(body.position + delta);
        else transform.position += (Vector3)delta;
    }
    public void Damage(float amount)
    {
        if (health <= 0) return;
        health = Mathf.Max(0, health - Mathf.Max(0, amount));
        if (health <= 0) { Died?.Invoke(this); gameObject.SetActive(false); }
    }
    public void Heal(float amount) { health = Mathf.Min(maxHealth, health + Mathf.Max(0, amount)); }
}
