using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class CameraEff : MonoBehaviour {

    Camera m_came;
    public Material m_affMaterail;

	// Use this for initialization
	void Start () {
        if (m_came == null)
            m_came = GetComponent<Camera>();

        m_came.depthTextureMode |= DepthTextureMode.Depth;
    }
	
	// Update is called once per frame
	void Update () {
		
	}

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (m_affMaterail != null)
        {
            Graphics.Blit(source, destination,m_affMaterail);
        }
        else
            Graphics.Blit(source, destination);
    }
}
