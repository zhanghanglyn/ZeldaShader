using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class GetUV : MonoBehaviour
{
    public GameObject GetuvGameObject;
    Vector2[] meshUv;
    Material gameObjMeterial;
    // Start is called before the first frame update
    void Start()
    {
        if (GetuvGameObject != null)
        {
            SkinnedMeshRenderer sk_MeshRender = GetuvGameObject.GetComponent<SkinnedMeshRenderer>();
            if (sk_MeshRender != null)
            {
                Mesh tempMesh = new Mesh() ;
                sk_MeshRender.BakeMesh(tempMesh);
                meshUv = tempMesh.uv;
                tempMesh.Clear();

                gameObjMeterial = gameObject.GetComponent<SkinnedMeshRenderer>().sharedMaterial;
                
            }
        }
    }

    // Update is called once per frame
    void Update()
    {
        if(gameObjMeterial != null)
            gameObjMeterial.SetVector("_ExUv", meshUv[1]);

    }
}
