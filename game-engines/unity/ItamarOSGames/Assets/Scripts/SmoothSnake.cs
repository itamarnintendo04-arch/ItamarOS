using UnityEngine;
using System.Collections.Generic;

/// Grid-aligned turns with continuous pixel movement and an interpolated body.
public class SmoothSnake : MonoBehaviour
{
    public float cellSize = 0.5f;
    public float speed = 3f;
    public float speedIncrease = 0.2f;
    public int initialSegments = 5;
    public Transform segmentPrefab;
    public Transform cherry;
    public Vector2 bounds = new Vector2(9f, 5f);
    public int score { get; private set; }
    private Vector2 direction = Vector2.right;
    private Vector2 requested = Vector2.right;
    private readonly List<Transform> segments = new List<Transform>();
    private readonly List<Vector3> trail = new List<Vector3>();
    private float stepProgress;

    void Start()
    {
        trail.Add(transform.position);
        if (segmentPrefab)
            for (int i = 0; i < initialSegments; i++)
            {
                var part = Instantiate(segmentPrefab, transform.position - Vector3.right * cellSize * (i+1), Quaternion.identity);
                segments.Add(part);
            }
        SpawnCherry();
    }
    public void Turn(Vector2 input)
    {
        if (Mathf.Abs(input.x) > Mathf.Abs(input.y)) requested = new Vector2(Mathf.Sign(input.x), 0);
        else if (Mathf.Abs(input.y) > 0.01f) requested = new Vector2(0, Mathf.Sign(input.y));
    }
    void Update()
    {
        float remaining = speed * Time.deltaTime;
        while (remaining > 0)
        {
            float portion = Mathf.Min(remaining, cellSize - stepProgress);
            transform.position += (Vector3)(direction * portion);
            stepProgress += portion;
            remaining -= portion;
            if (stepProgress >= cellSize - 0.0001f)
            {
                stepProgress = 0;
                var aligned = (Vector2)transform.position;
                aligned = new Vector2(Mathf.Round(aligned.x / cellSize) * cellSize,
                                      Mathf.Round(aligned.y / cellSize) * cellSize);
                transform.position = aligned;
                trail.Insert(0, transform.position);
                if (trail.Count > 5000) trail.RemoveAt(trail.Count - 1);
                if (Vector2.Dot(requested, direction) >= 0) direction = requested;
                if (Mathf.Abs(aligned.x) > bounds.x || Mathf.Abs(aligned.y) > bounds.y)
                    { enabled = false; return; }
            }
        }
        for (int i = 0; i < segments.Count; i++)
        {
            int a = Mathf.Min(i + 1, trail.Count - 1);
            int b = Mathf.Min(i + 2, trail.Count - 1);
            segments[i].position = Vector3.Lerp(trail[b], trail[a], stepProgress / cellSize);
        }
        if (cherry && Vector2.Distance(transform.position, cherry.position) < cellSize * 0.65f)
        {
            score++;
            speed += speedIncrease;
            if (segmentPrefab) segments.Add(Instantiate(segmentPrefab, segments.Count > 0 ? segments[segments.Count-1].position : transform.position, Quaternion.identity));
            SpawnCherry();
        }
        foreach (var part in segments)
            if (part && Vector2.Distance(transform.position, part.position) < cellSize * 0.4f &&
                Vector2.Distance(transform.position, part.position) > 0.0001f)
                { enabled = false; break; }
    }
    private void SpawnCherry()
    {
        if (!cherry) return;
        cherry.position = new Vector3(Mathf.Round(Random.Range(-bounds.x + cellSize, bounds.x - cellSize) / cellSize) * cellSize,
                                      Mathf.Round(Random.Range(-bounds.y + cellSize, bounds.y - cellSize) / cellSize) * cellSize, 0);
    }
}
