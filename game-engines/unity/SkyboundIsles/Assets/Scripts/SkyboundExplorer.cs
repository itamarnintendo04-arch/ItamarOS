using UnityEngine;

[RequireComponent(typeof(Rigidbody2D))]
public class SkyboundExplorer : MonoBehaviour
{
    public float runSpeed = 6f;
    public float jumpImpulse = 12f;
    public Transform groundCheck;
    public LayerMask ground;
    public int collectedCrystals;
    private Rigidbody2D body;
    private float horizontal;
    private bool jumpRequested;

    void Awake() { body = GetComponent<Rigidbody2D>(); }
    public void Move(float axis) { horizontal = Mathf.Clamp(axis, -1f, 1f); }
    public void Jump() { jumpRequested = true; }
    void FixedUpdate()
    {
        body.velocity = new Vector2(horizontal * runSpeed, body.linearVelocity.y);
        if (jumpRequested && groundCheck && Physics2D.OverlapCircle(groundCheck.position, 0.17f, ground))
            body.AddForce(Vector2.up * jumpImpulse, ForceMode2D.Impulse);
        jumpRequested = false;
    }
    void OnTriggerEnter2D(Collider2D other)
    {
        if (other.CompareTag("Crystal")) { collectedCrystals++; Destroy(other.gameObject); }
    }
}
