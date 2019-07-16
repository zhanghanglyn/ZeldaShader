using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class tttt : MonoBehaviour
{
    public GameObject uvOjb;
    Vector2[] uv;
    // Start is called before the first frame update
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        Material sharedMaterial = gameObject.GetComponent<SkinnedMeshRenderer>().sharedMaterial;
        Mesh aa  = uvOjb.GetComponent<Mesh>();
        if (aa != null)
        {
            sharedMaterial.SetVector("_Layer2UV", uv[0]);
        }

    }
}
